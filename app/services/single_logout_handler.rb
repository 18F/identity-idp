require 'saml_idp/logout_request_builder'

SingleLogoutHandler = Struct.new(:saml_response, :saml_request, :user) do
  def successful_saml_response?
    saml_response.present? && saml_response.success?
  end

  def finish_logout_at_idp?
    failed_saml_response? || slo_not_implemented_at_sp?
  end

  def valid_saml_request?
    saml_request.present? && saml_request.valid?
  end

  def request_message
    Base64.strict_encode64(slo_request_builder(
      sp_metadata,
      identity.uuid,
      identity.session_uuid
    ).signed)
  end

  def request_action_url
    sp_metadata[:assertion_consumer_logout_service_url]
  end

  private

  def failed_saml_response?
    saml_response.present? && !saml_response.success?
  end

  def slo_not_implemented_at_sp?
    identity.sp_metadata[:assertion_consumer_logout_service_url].blank?
  end

  def identity
    return NullIdentity.new unless user

    @_identity ||= begin
      first_identity = user.first_identity

      if first_identity && saml_request && saml_request.issuer != first_identity.service_provider
        return first_identity
      end
      # Logout was initiated out of chronological order. Resume SLO
      # with next Identity
      return second_identity if second_identity
      # fallback to last authenticated identity (for 3+ SP envs)
      user.last_identity
    end
  end

  def second_identity
    user.active_identities[1]
  end

  def sp_metadata
    identity.sp_metadata
  end

  def slo_request_builder(sp_data, name_id, session_index)
    @_slo_request_builder ||= SamlIdp::LogoutRequestBuilder.new(
      session_index,
      saml_idp_config.base_saml_location,
      sp_data[:assertion_consumer_logout_service_url],
      name_id,
      saml_idp_config.algorithm
    )
  end

  def saml_idp_config
    @_saml_idp_config ||= SamlIdp.config
  end
end
