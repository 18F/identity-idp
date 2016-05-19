require 'saml_idp_constants'
require 'saml_idp'
require 'uuid'

# rubocop:disable ClassLength
class SamlIdpController < ApplicationController
  include SamlIdp::Controller
  include SamlIdpLogoutConcern

  skip_before_action :verify_authenticity_token

  before_action :disable_caching
  before_action :validate_saml_request, only: :auth
  before_action :validate_saml_logout_param, only: :logout
  before_action :store_sp_data, only: :auth
  before_action :confirm_two_factor_authenticated, except: [:metadata, :logout]

  def auth
    use_secure_headers_override(:saml)

    unless valid_authn_contexts.include?(requested_authn_context)
      process_invalid_authn_context
      return
    end

    render_template_for(saml_response, saml_response_url, 'SAMLResponse')
  end

  def metadata
    render inline: SamlIdp.metadata.build.to_xml, content_type: 'text/xml'
  end

  def logout
    message = saml_logout_message

    return finish_slo_at_idp if message.nil? || message[:message].blank?

    sign_out current_user if message[:action] == 'sign out'

    render_template_for(
      Base64.strict_encode64(message[:message]),
      message[:action_url],
      message[:message_type]
    )
  end

  private

  def assure_sign_out_before_idv
    return if user_reauthed?
    sign_out(current_user) if current_user && ial_token
    store_saml_request_in_session
  end

  def user_reauthed?
    return unless current_user
    session[:forced_idv_sign_out] == current_user.ial_token && session.delete('SAMLRequest') ||
      current_user.second_factor_confirmed_at.nil? && session.delete('SAMLRequest')
  end

  def finish_slo_at_idp
    sign_out_with_flash
    redirect_to after_sign_out_path_for(:user)
  end

  def sign_out_with_flash
    sign_out current_user if user_signed_in?
    flash[:success] = I18n.t('devise.sessions.signed_out')
  end

  def disable_caching
    expires_now
    response.headers['Pragma'] = 'no-cache'
  end

  def store_sp_data
    session[:sp_data] = {
      provider: saml_request.service_provider.identifier,
      authn_context: requested_authn_context
    }

    return if relay_state_params.blank?

    session[:sp_data].merge!(ial_token: ial_token)
  end

  def valid_authn_contexts
    [Saml::Idp::Constants::LOA1_AUTHNCONTEXT_CLASSREF,
     Saml::Idp::Constants::LOA3_AUTHNCONTEXT_CLASSREF]
  end

  def process_invalid_authn_context
    logger.info "Invalid authn context #{requested_authn_context} requested"
    render nothing: true, status: :bad_request
  end

  def authn_context_node
    saml_request.document.xpath(
      '//samlp:AuthnRequest/samlp:RequestedAuthnContext/saml:AuthnContextClassRef',
      samlp: Saml::XML::Namespaces::PROTOCOL,
      saml: Saml::XML::Namespaces::ASSERTION)
  end

  def requested_authn_context
    return authn_context_node[0].content if authn_context_node.length == 1

    logger.info 'authn_context is missing'
    nil
  end

  def logout_response_builder
    SamlIdp::LogoutResponseBuilder.new(
      get_saml_response_id,
      issuer_uri,
      saml_response_url,
      saml_request.request_id,
      signature_opts)
  end

  def check_ial_token
    return if current_user.identity_verified?
    route_idv_request if ial_token
  end

  def route_idv_request
    store_saml_request_in_session
    link_identity_from_session_data
    redirect_to idp_index_url
  end

  # stores original SAMLRequest in session to continue SAML Authn flow
  def store_saml_request_in_session
    session[:SAMLRequest] = request.original_url
  end

  def relay_state_params
    JSON.parse(URI.unescape(params.fetch('RelayState', '{}')))
  end

  def ial_token
    relay_state_params['token'] || relay_state_params['ial_token']
  end

  def validate_saml_logout_param
    prepare_saml_logout_response if params[:SAMLResponse].present?
    prepare_saml_logout_request if params[:SAMLRequest].present?
  end

  def prepare_saml_logout_response
    @saml_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse])
  end

  def prepare_saml_logout_request
    validate_saml_request
    return if session[:logout_response]
    # store originating SP's logout response in the user session
    # for final step in SLO
    session[:logout_response] = logout_response_builder.build.to_xml
    session[:logout_response_url] = saml_response_url
  end

  def saml_response
    encode_response(
      current_user,
      authn_context_classref: requested_authn_context,
      reference_id: auth_identity.session_uuid.gsub(/^_/, '')
    )
  end

  def render_template_for(message, action_url, type)
    render(
      template: 'saml_idp/shared/saml_post_binding',
      locals: {
        action_url: action_url,
        message: message,
        type: type
      },
      layout: false
    )
  end

  def auth_identity
    current_user.set_active_identity(
      saml_request.service_provider.identifier,
      requested_authn_context,
      true
    )
  end
end
# rubocop:enable ClassLength
