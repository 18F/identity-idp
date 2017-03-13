# rubocop:disable Metrics/ClassLength
class OpenidConnectAuthorizeForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  SIMPLE_ATTRS = %i(
    client_id
    code_challenge
    code_challenge_method
    nonce
    prompt
    redirect_uri
    response_type
    state
  ).freeze

  ATTRS = [:acr_values, :scope, *SIMPLE_ATTRS].freeze

  attr_reader(*ATTRS)

  validates_presence_of :acr_values,
                        :client_id,
                        :prompt,
                        :redirect_uri,
                        :scope,
                        :state

  validates_inclusion_of :response_type, in: %w(code)
  validates_inclusion_of :prompt, in: %w(select_account)
  validates_inclusion_of :code_challenge_method, in: %w(S256), if: :code_challenge

  validate :validate_acr_values
  validate :validate_client_id
  validate :validate_redirect_uri
  validate :validate_redirect_uri_matches_sp_redirect_uri
  validate :validate_scope

  def initialize(params)
    @acr_values = parse_to_values(params[:acr_values], Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
    @scope = parse_to_values(params[:scope], OpenidConnectAttributeScoper::VALID_SCOPES)
    SIMPLE_ATTRS.each do |key|
      instance_variable_set(:"@#{key}", params[key])
    end
  end

  def submit(user, rails_session_id)
    @success = valid?

    link_identity_to_client_id(user, rails_session_id) if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def loa3_requested?
    ial == 3
  end

  def sp_redirect_uri
    service_provider.redirect_uri
  end

  def service_provider
    @_service_provider ||= ServiceProvider.from_issuer(client_id)
  end

  private

  attr_reader :identity, :success

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
    _uri = URI(redirect_uri)
  rescue ArgumentError, URI::InvalidURIError
    errors.add(:redirect_uri, t('openid_connect.authorization.errors.redirect_uri_invalid'))
  end

  def validate_redirect_uri_matches_sp_redirect_uri
    return if redirect_uri.blank?
    return unless service_provider.active?
    return if redirect_uri.start_with?(sp_redirect_uri)
    errors.add(:redirect_uri, t('openid_connect.authorization.errors.redirect_uri_no_match'))
  end

  def validate_scope
    return if scope.present?
    errors.add(:scope, t('openid_connect.authorization.errors.no_valid_scope'))
  end

  def link_identity_to_client_id(current_user, rails_session_id)
    identity_linker = IdentityLinker.new(current_user, client_id)
    @identity = identity_linker.link_identity(
      nonce: nonce,
      rails_session_id: rails_session_id,
      ial: ial,
      scope: scope.join(' '),
      code_challenge: code_challenge
    )
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

  def success_redirect_uri
    URIService.add_params(redirect_uri, code: identity.session_uuid, state: state)
  end

  def error_redirect_uri
    URIService.add_params(
      redirect_uri,
      error: 'invalid_request',
      error_description: errors.full_messages.join(' '),
      state: state
    )
  end
end
# rubocop:enable Metrics/ClassLength
