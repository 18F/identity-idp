# frozen_string_literal: true

class OpenidConnectAuthorizeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include RedirectUriValidator
  extend Forwardable

  SIMPLE_ATTRS = %i[
    client_id
    code_challenge
    code_challenge_method
    dpop_jkt
    nonce
    prompt
    redirect_uri
    response_type
    site_key_jwk
    state
  ].freeze

  ATTRS = [
    :unauthorized_scope,
    :acr_values,
    :scope,
    :verified_within,
    *SIMPLE_ATTRS,
  ].freeze

  AALS_BY_PRIORITY = [Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF].freeze
  IALS_BY_PRIORITY = [Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
                      Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR,
                      Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::IAL_VERIFIED_ACR,
                      Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
                      Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF].freeze

  attr_reader(*ATTRS)

  RANDOM_VALUE_MINIMUM_LENGTH = 22
  # A base64url SHA-256 without padding, 43 characters: the shape of an S256 PKCE code challenge
  # and of an RFC 7638 key thumbprint.
  BASE64URL_SHA256_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
  MINIMUM_REPROOF_VERIFIED_WITHIN_DAYS = 30

  validates :acr_values, presence: true
  validates :client_id, presence: true
  validates :redirect_uri, presence: true
  validates :scope, presence: true
  validates :state, presence: true, length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH }
  validates :nonce, presence: true, length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH }

  validates :response_type, inclusion: { in: %w[code] }
  validates :prompt, presence: true, inclusion: { in: %w[create login select_account] }
  validates :code_challenge_method, inclusion: { in: %w[S256] },
                                    if: :validate_code_challenge_method?
  validate :validate_pkce_parameter_pair, if: :private_key_jwt_pkce_enabled?
  validates :code_challenge, format: { with: BASE64URL_SHA256_FORMAT },
                             if: :private_key_jwt_pkce_requested?

  validate :validate_acr_values
  validate :validate_client_id
  validate :validate_scope
  validate :validate_unauthorized_scope
  validate :validate_privileges
  validate :validate_delegation_scopes
  validate :validate_dpop_jkt
  validate :validate_document_images_scope
  validate :validate_site_key_jwk
  validate :validate_prompt
  validate :validate_verified_within_format, if: :verified_within_allowed?
  validate :validate_verified_within_duration, if: :verified_within_allowed?

  def initialize(params)
    @acr_values = parse_to_values(params[:acr_values], Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
    SIMPLE_ATTRS.each { |key| instance_variable_set(:"@#{key}", params[key]) }
    @prompt ||= 'select_account'
    @scoper = OpenidConnectAttributeScoper.new(params[:scope], allowed: scopes)
    @scope = scoper.scopes
    @unauthorized_scope = check_for_unauthorized_scope(params)

    if verified_within_allowed?
      @duration_parser = DurationParser.new(params[:verified_within])
      @verified_within = @duration_parser.parse
    end
  end

  def submit
    @success = valid?

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def verified_at_requested?
    scope.include?('profile:verified_at')
  end

  def cannot_validate_redirect_uri?
    errors.include?(:redirect_uri) || errors.include?(:client_id)
  end

  def service_provider
    return @service_provider if defined?(@service_provider)
    @service_provider =
      if client_id.blank?
        nil
      else
        ServiceProvider.find_by(issuer: client_id)
      end
  end

  def link_identity_to_service_provider(
    current_user:,
    ial:,
    rails_session_id:,
    email_address_id:
  )
    identity_linker = IdentityLinker.new(current_user, service_provider)
    @identity = identity_linker.link_identity(
      nonce: nonce,
      rails_session_id: rails_session_id,
      ial: ial,
      acr_values: acr_values&.join(' '),
      requested_aal_value: requested_aal_value,
      scope: server_scope.join(' '),
      code_challenge: code_challenge,
      private_key_jwt_pkce: private_key_jwt_pkce_requested?,
      email_address_id: email_address_id,
      dpop_jkt: (dpop_jkt if dpop_binding_required?),
    )
  end

  def success_redirect_uri
    return if cannot_validate_redirect_uri?
    code = identity&.session_uuid

    UriService.add_params(redirect_uri, code: code, state: state) if code
  end

  def ial_values
    IALS_BY_PRIORITY & acr_values
  end

  def aal_values
    AALS_BY_PRIORITY & acr_values
  end

  def requested_aal_value
    highest_level_aal(aal_values) ||
      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
  end

  def initiate_user_registration?
    prompt == 'create'
  end

  # Bare delegation scope values: the applications the service provider asks to act at for the
  # user, requested as `token_exchange:<value>` in the OIDC scope parameter.
  def requested_delegation_scopes
    scoper.delegation_scope_values
  end

  def delegation_requested?
    requested_delegation_scopes.any?
  end

  # With a site key, email is sealed into the browser-only fragment instead, so the identity
  # (and therefore the ID token and userinfo the RP server reads) never carries it.
  def server_scope
    site_key_requested? ? scope - %w[email all_emails] : scope
  end

  def site_key_requested?
    site_key_jwk.present? && service_provider&.site_key_allowed?
  end

  # Whether every token this client receives is bound to a key it holds (RFC 9449). Binding
  # follows the client type alone: a public client (PKCE, no client secret) approved for
  # delegated access holds its tokens in the person's browser, so each must be useless without
  # the key. Confidential clients, and public clients not approved for delegation, receive bearer
  # tokens as before.
  def dpop_binding_required?
    service_provider&.pkce == true && service_provider.delegation_service_provider?
  end

  private

  attr_reader :identity, :success, :scoper

  def private_key_jwt_sp?
    # Missing service providers are rejected by validate_client_id.
    service_provider&.pkce == false
  end

  def private_key_jwt_pkce_enabled?
    IdentityConfig.store.openid_connect_private_key_jwt_pkce_enabled && private_key_jwt_sp?
  end

  def pkce_parameters_provided?
    [code_challenge, code_challenge_method].compact.present?
  end

  def pkce_requested?
    code_challenge.present? && code_challenge_method.present?
  end

  def private_key_jwt_pkce_requested?
    private_key_jwt_pkce_enabled? && pkce_requested?
  end

  def validate_code_challenge_method?
    # Preserve the original truthiness check for disabled and legacy flows, including empty strings.
    private_key_jwt_pkce_enabled? ? pkce_requested? : !!code_challenge
  end

  def validate_pkce_parameter_pair
    return unless pkce_parameters_provided?
    return if pkce_requested?

    errors.add(
      :base,
      t('openid_connect.authorization.errors.pkce_parameter_pair'),
      type: :pkce_parameter_pair,
    )
  end

  def code
    identity&.session_uuid
  end

  def check_for_unauthorized_scope(params)
    param_value = params[:scope]
    return false if identity_proofing_requested_or_default? || param_value.blank?
    return true if verified_at_requested? && !identity_proofing_service_provider?
    @scope != param_value.split(' ').compact
  end

  def parse_to_values(param_value, possible_values)
    return [] if param_value.blank?
    param_value.split(' ').compact & possible_values
  end

  # Delegation may be requested only by a service provider approved for it, only on an
  # identity-verified request, and only for registered, active applications that accept this
  # service provider. Anything else is reported to the service provider as invalid_scope so the
  # person never sees a choice that cannot be honored.
  def validate_delegation_scopes
    requested = requested_delegation_scopes
    return if requested.empty?

    unless service_provider&.delegation_service_provider? && identity_proofing_requested_or_default?
      errors.add(
        :scope, t('openid_connect.authorization.errors.delegation_not_allowed'),
        type: :delegation_not_allowed
      )
      return
    end

    known = DelegationApplications.accepting(client_id).map(&:delegation_scope_value)
    unknown = requested - known
    return if unknown.empty?

    errors.add(
      :scope,
      t('openid_connect.authorization.errors.unknown_delegation_scope', scopes: unknown.join(', ')),
      type: :unknown_delegation_scope,
    )
  end

  # RFC 9449 §10: a public client approved for delegation names the thumbprint of its DPoP key in
  # the authorization request, so the code it receives can be redeemed only with a proof from that
  # key and an intercepted code is worthless. Any client may send a well-formed thumbprint; it is
  # stored only when binding applies to the client.
  def validate_dpop_jkt
    if dpop_jkt.blank?
      return unless dpop_binding_required?

      errors.add(
        :dpop_jkt, t('openid_connect.authorization.errors.dpop_jkt_required'),
        type: :dpop_jkt_required
      )
    elsif !dpop_jkt.match?(BASE64URL_SHA256_FORMAT)
      errors.add(
        :dpop_jkt, t('openid_connect.authorization.errors.dpop_jkt_invalid'),
        type: :dpop_jkt_invalid
      )
    end
  end

  def delegation_scope_error?
    errors.details[:scope].to_a.any? do |detail|
      %i[delegation_not_allowed unknown_delegation_scope].include?(detail[:type])
    end
  end

  def validate_acr_values
    if acr_values.empty?
      errors.add(
        :acr_values, t('openid_connect.authorization.errors.no_valid_acr_values'),
        type: :no_valid_acr_values
      )
    elsif ial_values.empty?
      errors.add(
        :acr_values, t('openid_connect.authorization.errors.missing_ial'),
        type: :missing_ial
      )
    end
  end

  # This checks that the SP matches something in the database
  # OpenidConnect::AuthorizationController#check_sp_active checks that it's currently active
  def validate_client_id
    return if service_provider
    errors.add(
      :client_id, t('openid_connect.authorization.errors.bad_client_id'),
      type: :bad_client_id
    )
  end

  def validate_scope
    return if scope.present?
    errors.add(
      :scope, t('openid_connect.authorization.errors.no_valid_scope'),
      type: :no_valid_scope
    )
  end

  def validate_unauthorized_scope
    return unless @unauthorized_scope && IdentityConfig.store.unauthorized_scope_enabled
    errors.add(
      :scope, t('openid_connect.authorization.errors.unauthorized_scope'),
      type: :unauthorized_scope
    )
  end

  def validate_document_images_scope
    return unless scope.include?('document_images')
    return if service_provider&.document_images_sharing_allowed?

    errors.add(
      :scope, t('openid_connect.authorization.errors.no_valid_scope'),
      type: :no_valid_scope
    )
  end

  def validate_site_key_jwk
    return if site_key_jwk.blank?

    unless service_provider&.site_key_allowed?
      return errors.add(
        :site_key_jwk, t('openid_connect.authorization.errors.site_key_jwk_not_allowed'),
        type: :site_key_jwk_not_allowed
      )
    end

    SiteKeys::RecipientJwk.parse(site_key_jwk)
  rescue SiteKeys::SealError
    errors.add(
      :site_key_jwk, t('openid_connect.authorization.errors.site_key_jwk_invalid'),
      type: :site_key_jwk_invalid
    )
  end

  def validate_prompt
    return if prompt == 'select_account'
    return if prompt == 'login' && service_provider&.allow_prompt_login
    return if prompt == 'create' && service_provider&.create_prompt_allowed?

    errors.add(
      :prompt, t('openid_connect.authorization.errors.prompt_invalid'),
      type: :prompt_invalid
    )
  end

  def validate_verified_within_format
    return true if @duration_parser.valid?

    errors.add(
      :verified_within,
      t('openid_connect.authorization.errors.invalid_verified_within_format'),
      type: :invalid_verified_within_format,
    )
    false
  end

  def validate_verified_within_duration
    return true if verified_within.blank?
    return true if verified_within >= MINIMUM_REPROOF_VERIFIED_WITHIN_DAYS.days

    errors.add(
      :verified_within,
      t(
        'openid_connect.authorization.errors.invalid_verified_within_duration',
        count: MINIMUM_REPROOF_VERIFIED_WITHIN_DAYS,
      ),
      type: :invalid_verified_within_duration,
    )
    false
  end

  def extra_analytics_attributes
    {
      client_id: client_id,
      prompt: prompt,
      allow_prompt_login: service_provider&.allow_prompt_login,
      allow_prompt_create: service_provider&.create_prompt_allowed?,
      redirect_uri: result_uri,
      scope: scope&.sort&.join(' '),
      acr_values: acr_values&.sort&.join(' '),
      unauthorized_scope: @unauthorized_scope,
      delegation_scopes: requested_delegation_scopes.presence,
      code_digest: code ? Digest::SHA256.hexdigest(code) : nil,
      code_challenge_present: code_challenge.present?,
      service_provider_pkce: service_provider&.pkce,
      integration_errors:,
    }
  end

  def result_uri
    success ? success_redirect_uri : error_redirect_uri
  end

  def error_redirect_uri
    return if cannot_validate_redirect_uri?

    UriService.add_params(
      redirect_uri,
      # RFC 6749 §4.1.2.1: a bad or unauthorized scope value is invalid_scope, not invalid_request.
      error: delegation_scope_error? ? 'invalid_scope' : 'invalid_request',
      error_description: errors.full_messages.join(' '),
      state: state,
    )
  end

  def scopes
    if identity_proofing_requested_or_default?
      return OpenidConnectAttributeScoper::VALID_SCOPES
    end
    OpenidConnectAttributeScoper::VALID_IAL1_SCOPES
  end

  def validate_privileges
    if (identity_proofing_requested? && !identity_proofing_service_provider?) ||
       (ialmax_requested? && !ialmax_allowed_for_sp?) ||
       (facial_match_ial_requested? && !identity_proofing_service_provider?)
      errors.add(
        :acr_values, t('openid_connect.authorization.errors.no_auth'),
        type: :no_auth
      )
    end
  end

  def identity_proofing_requested_or_default?
    identity_proofing_requested? ||
      ialmax_requested? ||
      sp_defaults_to_identity_proofing?
  end

  def sp_defaults_to_identity_proofing?
    ial_values.blank? && identity_proofing_service_provider?
  end

  def identity_proofing_requested?
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL[ial_values.sort.max] == 2
  end

  def identity_proofing_service_provider?
    service_provider&.ial.to_i >= 2
  end

  def ialmax_allowed_for_sp?
    IdentityConfig.store.allowed_ialmax_providers.include?(client_id)
  end

  def ialmax_requested?
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL[ial_values.sort.max] == 0
  end

  def integration_errors
    return nil if @success || client_id.blank?

    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: :oidc_request_authorization,
      integration_exists: service_provider.present?,
      request_issuer: client_id,
    }
  end

  def facial_match_ial_requested?
    ial_values.any? { |ial| Saml::Idp::Constants::FACIAL_MATCH_IAL_CONTEXTS.include? ial }
  end

  def highest_level_aal(aal_values)
    AALS_BY_PRIORITY.find { |aal| aal_values.include?(aal) }
  end

  def verified_within_allowed?
    IdentityConfig.store.allowed_verified_within_providers.include?(client_id)
  end
end
