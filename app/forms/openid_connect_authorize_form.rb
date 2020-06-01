# rubocop:disable Metrics/ClassLength
class OpenidConnectAuthorizeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include RedirectUriValidator

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

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def ial2_service_provider?
    service_provider.ial == 2
  end

  def ial2_requested?
    ial == 2 && !service_provider.liveness_checking_required
  end

  def ial3_requested?
    ial == 3 || (ial == 2 && service_provider.liveness_checking_required)
  end

  def ialmax_requested?
    ial&.zero?
  end

  def verified_at_requested?
    scope.include?('profile:verified_at')
  end

  def service_provider
    @_service_provider ||= ServiceProvider.from_issuer(client_id)
  end

  def link_identity_to_service_provider(current_user, rails_session_id)
    identity_linker = IdentityLinker.new(current_user, client_id)
    @identity = identity_linker.link_identity(
      nonce: nonce,
      rails_session_id: rails_session_id,
      ial: ial,
      scope: scope.join(' '),
      code_challenge: code_challenge,
    )
  end

  def success_redirect_uri
    uri = redirect_uri unless errors.include?(:redirect_uri)
    code = identity&.session_uuid

    URIService.add_params(uri, code: code, state: state) if code
  end

  private

  attr_reader :identity, :success

  def check_for_unauthorized_scope(params)
    return true if ial3_requested_but_disabled?
    param_value = params[:scope]
    return false if ial2_requested? || ial3_requested? || param_value.blank?
    return true if verified_at_requested? && !ial2_service_provider?
    @scope != param_value.split(' ').compact
  end

  def ial3_requested_but_disabled?
    ial3_requested? && !FeatureManagement.liveness_checking_enabled?
  end

  def parse_to_values(param_value, possible_values)
    return [] if param_value.blank?
    param_value.split(' ').compact & possible_values
  end

  def validate_acr_values
    return if acr_values.present?
    errors.add(:acr_values, t('openid_connect.authorization.errors.no_valid_acr_values'))
  end

  def validate_client_id
    return if service_provider.active?
    errors.add(:client_id, t('openid_connect.authorization.errors.bad_client_id'))
  end

  def validate_scope
    return if scope.present?
    errors.add(:scope, t('openid_connect.authorization.errors.no_valid_scope'))
  end

  def validate_unauthorized_scope
    return unless @unauthorized_scope && Figaro.env.unauthorized_scope_enabled == 'true'
    errors.add(:scope, t('openid_connect.authorization.errors.unauthorized_scope'))
  end

  def validate_prompt
    return if prompt == 'select_account'
    return if prompt == 'login' && service_provider.allow_prompt_login
    errors.add(:prompt, t('openid_connect.authorization.errors.prompt_invalid'))
  end

  def validate_verified_within_format
    return true if @duration_parser.valid?

    errors.add(:verified_within,
               t('openid_connect.authorization.errors.invalid_verified_within_format'))
    false
  end

  def validate_verified_within_duration
    return true if verified_within.blank?
    return true if verified_within >= MINIMUM_REPROOF_VERIFIED_WITHIN_DAYS.days

    errors.add(:verified_within,
               t('openid_connect.authorization.errors.invalid_verified_within_duration',
                 count: MINIMUM_REPROOF_VERIFIED_WITHIN_DAYS))
    false
  end

  def ial
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_IAL[acr_values.sort.max]
  end

  def extra_analytics_attributes
    {
      client_id: client_id,
      redirect_uri: result_uri,
      unauthorized_scope: @unauthorized_scope,
    }
  end

  def result_uri
    success ? success_redirect_uri : error_redirect_uri
  end

  def error_redirect_uri
    uri = redirect_uri unless errors.include?(:redirect_uri)

    URIService.add_params(
      uri,
      error: 'invalid_request',
      error_description: errors.full_messages.join(' '),
      state: state,
    )
  end

  def scopes
    if ialmax_requested? || ial2_requested? || ial3_requested?
      return OpenidConnectAttributeScoper::VALID_SCOPES
    end
    OpenidConnectAttributeScoper::VALID_IAL1_SCOPES
  end

  def validate_privileges
    if (ial2_requested? && !ial2_service_provider?) ||
       (ialmax_requested? && !ial2_service_provider?)
      errors.add(:acr_values, t('openid_connect.authorization.errors.no_auth'))
    end
  end
end
# rubocop:enable Metrics/ClassLength
