# Although this module is long all the code is related to the SLO concern.
require 'saml_idp/logout_response_builder'

module SamlIdpLogoutConcern
  extend ActiveSupport::Concern

  private

  def slo
    @_slo ||= SingleLogoutHandler.new(@saml_response, saml_request, user)
  end

  def handle_saml_logout_response
    handler = LogoutResponseHandler.new(asserted_identity, slo_session[:logout_response])

    handler.deactivate_identity

    return generate_slo_request if handler.continue_logout_with_next_identity?

    handler.deactivate_last_identity

    return finish_slo_at_idp if handler.no_more_logout_responses?

    generate_slo_response_and_sign_out
  end

  def generate_slo_request
    render_template_for(slo.request_message, slo.request_action_url, 'SAMLRequest')
  end

  def handle_saml_logout_request(resource)
    # multiple identities present. initiate logoff at first
    return generate_slo_request if resource.multiple_identities?

    # no more active identities available. deactivate the final identity,
    # log the user out, and send response to SP
    resource.first_identity.deactivate

    generate_slo_response_and_sign_out
  end

  def user
    current_user || name_id_user
  end

  def name_id_user
    sp_slo_identity&.user
  end

  def sp_slo_identity
    @_sp_slo_identity ||= begin
      AgencyIdentityLinker.sp_identity_from_uuid(name_id)
    end
  end

  def name_id
    saml_request&.name_id
  end

  def asserted_identity
    Identity.includes(:user).find_by(session_uuid: @saml_response.in_response_to.gsub(/^_/, ''))
  end

  def logout_response_builder
    SamlIdp::LogoutResponseBuilder.new(
      UUID.generate,
      saml_idp_config.base_saml_location,
      saml_request.response_url,
      saml_request.request_id,
      saml_idp_config.algorithm
    )
  end

  def prepare_saml_logout_response_and_request
    prepare_saml_logout_response if params[:SAMLResponse].present?
    prepare_saml_logout_request if params[:SAMLRequest].present?
  end

  def prepare_saml_logout_response
    @saml_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse])
  end

  def prepare_saml_logout_request
    return if slo_session[:logout_response]
    # store originating SP's logout response in the user session
    # for final step in SLO
    slo_session[:logout_response] = logout_response_builder.signed
    slo_session[:logout_response_url] = saml_request.response_url
  end

  def finish_slo_at_idp
    sign_out_with_flash
    redirect_to root_url
  end

  def sign_out_with_flash
    sign_out if user_signed_in?
    flash[:success] = t('devise.sessions.signed_out')
  end

  def generate_slo_response_and_sign_out
    render_template_for(
      Base64.strict_encode64(slo_session[:logout_response]),
      slo_session[:logout_response_url],
      'SAMLResponse'
    )

    sign_out if user_signed_in?
  end

  def saml_idp_config
    @saml_idp_config ||= SamlIdp.config
  end

  def slo_session
    user_session || session
  end
end
