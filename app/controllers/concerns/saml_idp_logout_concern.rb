# rubocop:disable Metrics/ModuleLength
require 'saml_idp/logout_request_builder'
require 'saml_idp/logout_response_builder'
module SamlIdpLogoutConcern
  extend ActiveSupport::Concern

  def saml_logout_message
    return handle_saml_logout_response if successful_saml_response?
    return nil if failed_saml_response?
    return handle_saml_logout_request(name_id_user) if valid_saml_request?

    generate_slo_request(current_user) if user_signed_in_and_has_identity?
  end

  private

  def successful_saml_response?
    @saml_response.present? && @saml_response.success?
  end

  def failed_saml_response?
    @saml_response.present? && !@saml_response.success?
  end

  def valid_saml_request?
    saml_request.present? && saml_request.valid?
  end

  def user_signed_in_and_has_identity?
    user_signed_in? && current_user.active_identities.present?
  end

  def handle_saml_logout_response
    unless asserted_identity.nil?
      resource = asserted_identity.user
      asserted_identity.deactivate!
    end

    # continue logout with next identity if present
    return generate_slo_request(resource) if resource_in_slo?(resource)

    # no SLO messages to generate; finish logout at IdP
    return nil if session[:logout_response].nil?

    response = slo_response_from_session

    # transaction complete at IdP; terminate session, if it exists
    deactivate_session_and_identity(resource)
    response
  end

  def resource_in_slo?(resource)
    return true if resource && resource.multiple_identities?
    return true if
      resource && resource.active_identities.present? && session[:logout_response].nil?
    false
  end

  def generate_slo_request(resource)
    slo_identity = fetch_identity_for_slo(resource)
    {
      message: slo_request_builder(
        slo_identity.sp_metadata,
        resource.uuid,
        slo_identity.session_uuid).signed,
      action_url: slo_identity.sp_metadata[:assertion_consumer_logout_service_url],
      message_type: 'SAMLRequest'
    }
  end

  def fetch_identity_for_slo(resource)
    return resource.first_identity if
            saml_request &&
            saml_request.issuer != resource.first_identity.service_provider
    # Logout was initiated out of chronological order. Resume SLO
    # with next Identity
    return resource.active_identities[1] unless resource.active_identities[1].nil?
    # fallback to last authenticated identity (for 3+ SP envs)
    resource.last_identity
  end

  def slo_response_from_session
    # The response was generated with the originating request
    # and stored in session
    {
      message: session[:logout_response],
      action_url: session[:logout_response_url],
      message_type: 'SAMLResponse'
    }
  end

  def deactivate_session_and_identity(resource)
    resource.last_identity.deactivate! if resource.last_identity
    sign_out current_user if user_signed_in?
    clean_up_session
  end

  def handle_saml_logout_request(resource)
    # multiple identities present. initiate logoff at first
    return generate_slo_request(resource) if resource.multiple_identities?

    # no more active identities available. deactivate the final identity,
    # log the user out, and send response to SP
    resource.first_identity.deactivate! if resource.active_identities.present?

    {
      message: logout_response_builder.signed,
      action_url: saml_request.response_url,
      message_type: 'SAMLResponse',
      action: 'sign out'
    }
  end

  def name_id_user
    name_id = saml_request.name_id
    User.find_by(uuid: name_id)
  end

  def asserted_identity
    Identity.find_by(session_uuid: @saml_response.in_response_to)
  end

  def clean_up_session
    [:sp_data, :logout_response, :logout_response_url].each do |key|
      session.delete(key) if session[key]
    end
  end

  def slo_request_builder(sp_data, name_id, session_index)
    SamlIdp::LogoutRequestBuilder.new(
      session_index,
      SamlIdp.config.base_saml_location,
      sp_data[:assertion_consumer_logout_service_url],
      name_id,
      session_index,
      SamlIdp.config.algorithm
    )
  end

  def logout_response_builder
    SamlIdp::LogoutResponseBuilder.new(
      UUID.generate,
      SamlIdp.config.base_saml_location,
      saml_request.response_url,
      saml_request.request_id,
      SamlIdp.config.algorithm
    )
  end
end
# rubocop:enable Metrics/ModuleLength
