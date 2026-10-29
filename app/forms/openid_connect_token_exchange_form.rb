# frozen_string_literal: true

class OpenidConnectTokenExchangeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  ATTRS = %i[
    client_id
    grant_type
    subject_token
    subject_token_type
    audience
    resource
    requested_token_type
    scope
    acr_values
  ].freeze

  # The identity assurance levels an actor may ask for on the exchange, in the authorization
  # request's vocabulary: the verified values require an identity-verified identity at the
  # application, the others require nothing beyond the identity's existence.
  VERIFIED_ACR_VALUES = [
    Saml::Idp::Constants::IAL_VERIFIED_ACR,
    Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
  ].freeze
  UNVERIFIED_ACR_VALUES = [
    Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
    Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
  ].freeze

  # Parameters RFC 8693 section 2.1 requires on every token exchange request.
  # Omitting any of them is an `invalid_request`, not a grant or target failure.
  REQUIRED_ATTRS = %i[
    client_id
    grant_type
    subject_token
    subject_token_type
    audience
    resource
    requested_token_type
  ].freeze

  attr_reader(*ATTRS)

  validates(*REQUIRED_ATTRS, presence: true)
  validates :grant_type, inclusion: { in: [TokenExchange::Constants::GRANT_TYPE] }
  validates :subject_token_type,
            inclusion: { in: [TokenExchange::Constants::ACCESS_TOKEN_TYPE] }
  validates :requested_token_type,
            inclusion: { in: [TokenExchange::Constants::ACCESS_TOKEN_TYPE] }

  # Ordered cheapest first.
  validate :validate_enabled
  validate :validate_broker
  validate :validate_target
  validate :validate_resource
  validate :validate_acr_values
  validate :validate_subject_token, unless: :client_rejected?
  validate :validate_actor_return_log, unless: :client_rejected?
  validate :validate_scope, unless: :client_rejected?
  validate :validate_target_identity, unless: :client_rejected?
  validate :validate_assurance, unless: :client_rejected?

  def initialize(params)
    ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  # Validations perform a Redis read and database lookups. The controller asks
  # the form whether it is valid more than once per request, so memoize the
  # result. Safe because the form is built once per request and is read-only.
  def valid?
    return @valid if defined?(@valid)

    @valid = super
  end

  def submit
    success = valid?
    FormResponse.new(success:, errors:, extra: extra_analytics_attributes)
  end

  def response
    return error_response unless valid?

    {
      access_token: issued_token.token,
      issued_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
      token_type: 'Bearer',
      expires_in: issued_token.expires_in,
      scope: requested_scope,
    }
  end

  def delegation_id
    @issued_token&.delegation_id
  end

  # `invalid_client` indicates a client authentication failure, which RFC 6749
  # section 5.2 requires be returned with a 401.
  def http_status
    return :ok if valid?

    oauth_error == 'invalid_client' ? :unauthorized : :bad_request
  end

  private

  def validate_enabled
    return if token_exchange_enabled?

    errors.add(:grant_type, :inclusion)
  end

  def token_exchange_enabled?
    IdentityConfig.store.token_exchange_enabled
  end

  # True once the feature flag, the broker allowlist, or the target allowlist
  # has already rejected this request, so the remaining validations can skip
  # the Redis read and the identity lookup entirely.
  def client_rejected?
    !token_exchange_enabled? ||
      errors.include?(:client_id) ||
      errors.include?(:audience)
  end

  def validate_broker
    return if client_id.blank?
    return if broker&.token_exchange_broker?

    errors.add(:client_id, :invalid)
  end

  def validate_target
    return if audience.blank?
    return if target&.token_exchange_target?

    errors.add(:audience, :invalid)
  end

  def validate_subject_token
    return if subject_token.blank?
    return errors.add(:subject_token, :invalid) if loaded_subject_token.blank?
    return if loaded_subject_token.broker_issuer == client_id

    errors.add(:subject_token, :invalid)
  end

  def validate_actor_return_log
    return if loaded_subject_token.blank?
    return if actor_return_log.present?

    errors.add(:subject_token, :invalid)
  end

  def validate_resource
    return if resource.blank?

    uri = URI.parse(resource)
    return if uri.is_a?(URI::HTTPS) && uri.host.present?

    errors.add(:resource, :invalid)
  rescue URI::InvalidURIError
    errors.add(:resource, :invalid)
  end

  def validate_scope
    return if loaded_subject_token.blank? || requested_scope.blank?

    requested_scopes = requested_scope.split(' ')
    subject_scopes = loaded_subject_token.scope.to_s.split(' ')
    return if (requested_scopes - subject_scopes).blank?

    errors.add(:scope, :invalid)
  end

  # Delegation never creates the person's identity at the application: `sub` is the `identities`
  # row the person's own sign-in there created, read as it stands. A person without one is refused,
  # and the actor is told where that sign-in starts (`initiate_login_uri`, OpenID Connect Core 1.0
  # §4) so it can send the person there and ask again. Runs after every check on the subject token,
  # so a request already refused never reaches the lookup.
  def validate_target_identity
    return if errors.any?
    return errors.add(:subject_token, :invalid) if user.blank?
    return if target_identity.present?

    errors.add(
      :audience, :no_identity_at_target,
      message: t('openid_connect.token.errors.no_identity_at_target')
    )
  end

  def validate_acr_values
    return if acr_values.blank?
    return if (acr_values.split(' ') - VERIFIED_ACR_VALUES - UNVERIFIED_ACR_VALUES).empty?

    errors.add(
      :acr_values, :invalid,
      message: t('openid_connect.token.errors.acr_values_invalid')
    )
  end

  # The level the actor asked for is checked against the person's identity at the application,
  # which only that agency's own sign-in sets; the subject token's level is not, because a sign-in
  # at any level may delegate. A verified request also needs the person's Login.gov profile to be
  # active: the agency row is a snapshot set at the person's last identity-verified sign-in there,
  # and a password reset without the personal key or an encryption error deactivates the profile
  # since. A direct identity-verified sign-in at the agency would send the person to verify again,
  # so the hand-off does the same. Either shortfall is refused the way a missing identity is, with
  # the level named, so the actor can send the person to sign in at the agency at that level. A
  # request that asks for no level checks neither.
  def validate_assurance
    return if errors.any? || !verified_identity_requested?
    return if target_identity.ial.to_i >= 2 && user.active_profile.present?

    errors.add(
      :audience, :target_identity_assurance,
      message: t('openid_connect.token.errors.target_identity_assurance')
    )
  end

  def verified_identity_requested?
    acr_values.to_s.split(' ').intersect?(VERIFIED_ACR_VALUES)
  end

  def no_identity_at_target?
    errors.where(:audience, :no_identity_at_target).any?
  end

  def assurance_shortfall?
    errors.where(:audience, :target_identity_assurance).any?
  end

  def sign_in_at_agency_needed?
    no_identity_at_target? || assurance_shortfall?
  end

  def user
    identity&.user
  end

  def identity
    return @identity if defined?(@identity)
    return @identity = nil if loaded_subject_token.blank?

    @identity = ServiceProviderIdentity.find_by(
      uuid: loaded_subject_token.identity_uuid,
      service_provider: loaded_subject_token.broker_issuer,
    )
  end

  def actor_return_log
    return @actor_return_log if defined?(@actor_return_log)
    return @actor_return_log = nil if identity.blank?

    @actor_return_log = SpReturnLog.find_by(
      id: loaded_subject_token.actor_return_log_id,
      user_id: identity.user_id,
      issuer: loaded_subject_token.broker_issuer,
    )
  end

  def broker
    @broker ||= ServiceProvider.find_by(issuer: client_id)
  end

  def target
    @target ||= ServiceProvider.active.find_by(issuer: audience)
  end

  def target_identity
    return @target_identity if defined?(@target_identity)
    return @target_identity = nil if user.blank?

    @target_identity = user.identities.find_by(service_provider: audience)
  end

  def loaded_subject_token
    return @loaded_subject_token if defined?(@loaded_subject_token)

    @loaded_subject_token = TokenExchange::SubjectToken.load(subject_token)
  end

  def requested_scope
    scope.presence || loaded_subject_token&.scope
  end

  # A refusal that sends the person to sign in at the agency, for a missing identity there or one
  # below the level asked, also names the level asked and the application's login-initiation
  # address when one is registered (OpenID Connect Core 1.0 §4), so the actor can start that
  # sign-in. The actor is authenticated and the application registered by the time these checks
  # run, so the address is told to no one else.
  def error_response
    response = {
      error: oauth_error,
      error_description:,
    }
    return response unless sign_in_at_agency_needed?

    response[:acr_values] = acr_values if assurance_shortfall?
    initiate_login_uri = target&.token_exchange_initiate_login_uri
    response[:initiate_login_uri] = initiate_login_uri if initiate_login_uri.present?
    response
  end

  # A refusal that sends the person to the agency, or an `acr_values` Login.gov does not know, is
  # described by its own message; every other failure keeps the attribute-prefixed messages the
  # endpoint has always returned.
  def error_description
    return errors[:audience].join(' ') if sign_in_at_agency_needed?
    return errors[:acr_values].join(' ') if errors.include?(:acr_values)

    errors.full_messages.join(' ')
  end

  # Maps validation failures onto the OAuth error codes defined by RFC 6749
  # section 5.2 and extended by RFC 8693 section 2.2.2.
  def oauth_error
    return 'invalid_request' if missing_required_attrs?
    return 'unsupported_grant_type' if errors.include?(:grant_type)
    return 'invalid_client' if errors.include?(:client_id)
    return 'invalid_request' if errors.include?(:acr_values)
    return 'invalid_target' if errors.include?(:audience) || errors.include?(:resource)
    return 'invalid_scope' if errors.include?(:scope)

    'invalid_grant'
  end

  def missing_required_attrs?
    REQUIRED_ATTRS.any? do |attr|
      errors.where(attr, :blank).any?
    end
  end

  def extra_analytics_attributes
    {
      actor_issuer: client_id,
      target_issuer: audience,
      resource:,
      ial: subject_token_ial,
      token_exchange_stage: TokenExchange::Constants::STAGE_DELEGATED_TOKEN,
      token_exchange_scopes: token_exchange_scope_values,
      subject_token_fingerprint: subject_token_fingerprint,
      oauth_error_code: (oauth_error unless valid?),
      integration_errors:,
    }
  end

  def issued_token
    @issued_token ||= TokenExchange::AccessTokenIssuer.issue(
      subject_token: loaded_subject_token,
      target_identity:,
      target_issuer: audience,
      resource:,
      scope: requested_scope,
    )
  end

  def token_exchange_scope_values
    scopes = requested_scope.to_s.split(' ').select do |scope|
      TokenExchange::Constants.in_scope?(scope)
    end
    return if scopes.blank?

    scopes.map { |scope| scope.delete_prefix(TokenExchange::Constants::SCOPE_PREFIX) }
  end

  def subject_token_fingerprint
    TokenExchange::SubjectToken.digest(subject_token) if subject_token.present?
  end

  # Reports the IAL only when a validation already loaded the subject token.
  # Analytics must not be the thing that triggers the Redis read for a request
  # we rejected before reaching it.
  def subject_token_ial
    return unless defined?(@loaded_subject_token)

    @loaded_subject_token&.ial
  end

  def integration_errors
    return nil if valid?

    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: :oidc_token_request,
      integration_exists: broker.present?,
      request_issuer: client_id,
    }
  end
end
