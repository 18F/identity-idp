# rubocop:disable Metrics/ClassLength
class OpenidConnectAuthorizeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

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

  ATTRS = [:acr_values, :scope, *SIMPLE_ATTRS].freeze

  attr_reader(*ATTRS)

  RANDOM_VALUE_MINIMUM_LENGTH = 32

  validates :acr_values, presence: true
  validates :client_id, presence: true
  validates :redirect_uri, presence: true
  validates :scope, presence: true
  validates :state, presence: true, length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH }
  validates :nonce, presence: true, length: { minimum: RANDOM_VALUE_MINIMUM_LENGTH }

  validates :response_type, inclusion: { in: %w[code] }
  validates :prompt, presence: true, allow_nil: true, inclusion: { in: %w[login select_account] }
  validates :code_challenge_method, inclusion: { in: %w[S256] }, if: :code_challenge

  validate :validate_acr_values
  validate :validate_client_id
  validate :validate_redirect_uri
  validate :validate_scope

  def initialize(params)
    @acr_values = parse_to_values(params[:acr_values], Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
    @scope = parse_to_values(params[:scope], OpenidConnectAttributeScoper::VALID_SCOPES)
    SIMPLE_ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
    @prompt ||= 'select_account'

    @openid_connect_redirector = OpenidConnectRedirector.new(
      redirect_uri: redirect_uri, service_provider: service_provider, state: state, errors: errors
    )
  end

  def submit
    @success = valid?

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def loa3_requested?
    ial == 3
  end

  def sp_redirect_uri
    openid_connect_redirector.validated_input_redirect_uri
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
      code_challenge: code_challenge
    )
  end

  def success_redirect_uri
    code = identity&.session_uuid
    openid_connect_redirector.success_redirect_uri(code: code) if code
  end

  private

  attr_reader :identity, :success, :openid_connect_redirector, :already_linked

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

  def validate_redirect_uri
    openid_connect_redirector.validate
  end

  def validate_scope
    return if scope.present?
    errors.add(:scope, t('openid_connect.authorization.errors.no_valid_scope'))
  end

  def ial
    case acr_values.sort.max
    when Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
      1
    when Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
      3
    end
  end

  def extra_analytics_attributes
    {
      client_id: client_id,
      redirect_uri: result_uri,
    }
  end

  def result_uri
    success ? success_redirect_uri : error_redirect_uri
  end

  def error_redirect_uri
    openid_connect_redirector.error_redirect_uri
  end
end
# rubocop:enable Metrics/ClassLength
