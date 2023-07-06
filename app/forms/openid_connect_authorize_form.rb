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
    nonce
    prompt
    redirect_uri
    response_type
    state
  ].freeze

  ATTRS = [:unauthorized_scope, :acr_values, :scope, :verified_within, *SIMPLE_ATTRS].freeze
  AALS_BY_PRIORITY = [Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
                      Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF].freeze

  attr_reader(*ATTRS)

  RANDOM_VALUE_MINIMUM_LENGTH = 22
  MINIMUM_REPROOF_VERIFIED_WITHIN_DAYS = 30

  validates :acr_values, presence: true
  validates :client_id, presence: true
  validates :redirect_uri, presence: true
  validates :scope, presence: true
  validates :state, presence: true, length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH }
  validates :nonce, presence: true, length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH }

  validates :response_type, inclusion: { in: %w[code] }
  validates :prompt, presence: true, inclusion: { in: %w[login select_account] }
  validates :code_challenge_method, inclusion: { in: %w[S256] }, if: :code_challenge

  validate :validate_acr_values
  validate :validate_client_id
  validate :validate_scope
  validate :validate_unauthorized_scope
  validate :validate_privileges
  validate :validate_prompt
  validate :validate_verified_within_format
  validate :validate_verified_within_duration

  def initialize(params)
    @acr_values = parse_to_values(params[:acr_values], Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
    SIMPLE_ATTRS.each { |key| instance_variable_set(:"@#{key}", params[key]) }
    @prompt ||= 'select_account'
    @scope = parse_to_values(params[:scope], scopes)
    @unauthorized_scope = check_for_unauthorized_scope(params)

    @duration_parser = DurationParser.new(params[:verified_within])
    @verified_within = @duration_parser.parse
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
    @service_provider = ServiceProvider.find_by(issuer: client_id)
  end

  def link_identity_to_service_provider(current_user, rails_session_id)
    identity_linker = IdentityLinker.new(current_user, service_provider)
    @identity = identity_linker.link_identity(
      nonce: nonce,
      rails_session_id: rails_session_id,
      ial: ial_context.ial,
      aal: aal,
      requested_aal_value: requested_aal_value,
      scope: scope.join(' '),
      code_challenge: code_challenge,
    )
  end

  def success_redirect_uri
    return if cannot_validate_redirect_uri?
    code = identity&.session_uuid

    UriService.add_params(redirect_uri, code: code, state: state) if code
  end

  def ial_values
    acr_values.filter { |acr| %r{/ial/}.match?(acr) || %r{/loa/}.match?(acr) }
  end

  def ial_context
    @ial_context ||= IalContext.new(ial: ial, service_provider: service_provider)
  end

  def ial
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL[ial_values.sort.max]
  end

  def aal_values
    acr_values.filter { |acr| %r{/aal/}.match? acr }
  end

  def aal
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL[requested_aal_value]
  end

  def requested_aal_value
    highest_level_aal(aal_values) ||
      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
  end

  def_delegators :ial_context,
                 :ial2_or_greater?,
                 :ial2_requested?

  private

  attr_reader :identity, :success

  def code
    identity&.session_uuid
  end

  def check_for_unauthorized_scope(params)
    param_value = params[:scope]
    return false if ial2_or_greater? || param_value.blank?
    return true if verified_at_requested? && !ial_context.ial2_service_provider?
    @scope != param_value.split(' ').compact
  end

  def parse_to_values(param_value, possible_values)
    return [] if param_value.blank?
    param_value.split(' ').compact & possible_values
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

  def validate_prompt
    return if prompt == 'select_account'
    return if prompt == 'login' && service_provider&.allow_prompt_login
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
      redirect_uri: result_uri,
      scope: scope&.sort&.join(' '),
      acr_values: acr_values&.sort&.join(' '),
      unauthorized_scope: @unauthorized_scope,
      code_digest: code ? Digest::SHA256.hexdigest(code) : nil,
    }
  end

  def result_uri
    success ? success_redirect_uri : error_redirect_uri
  end

  def error_redirect_uri
    return if cannot_validate_redirect_uri?

    UriService.add_params(
      redirect_uri,
      error: 'invalid_request',
      error_description: errors.full_messages.join(' '),
      state: state,
    )
  end

  def scopes
    if ial_context.ialmax_requested? || ial2_or_greater?
      return OpenidConnectAttributeScoper::VALID_SCOPES
    end
    OpenidConnectAttributeScoper::VALID_IAL1_SCOPES
  end

  def validate_privileges
    if (ial2_requested? && !ial_context.ial2_service_provider?) ||
       (ial_context.ialmax_requested? &&
        !IdentityConfig.store.allowed_ialmax_providers.include?(client_id))
      errors.add(
        :acr_values, t('openid_connect.authorization.errors.no_auth'),
        type: :no_auth
      )
    end
  end

  def highest_level_aal(aal_values)
    AALS_BY_PRIORITY.find { |aal| aal_values.include?(aal) }
  end
end
