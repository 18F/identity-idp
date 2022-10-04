class StoreSpMetadataInSession
  def initialize(session:, request_id:)
    @session = session
    @request_id = request_id
  end

  def call
    Rails.logger.info(event_attributes)

    return if sp_request.is_a?(NullServiceProviderRequest)

    update_session
  end

  private

  attr_reader :session, :request_id

  def ial_context
    @ial_context ||= IalContext.new(ial: sp_request.ial, service_provider: service_provider)
  end

  def event_attributes
    {
      event: 'StoreSpMetadataInSession',
      request_id_present: request_id.present?,
      sp_request_class: sp_request.class.to_s,
    }.to_json
  end

  def sp_request
    @sp_request ||= ServiceProviderRequestProxy.from_uuid(request_id)
  end

  def update_session
    session[:sp] = {
      issuer: sp_request.issuer,
      ial: ial_context.ial,
      ial2: ial_context.ial2_requested?,
      ial2_strict: ial_context.ial2_strict_requested?,
      ialmax: ial_context.ialmax_requested?,
      aal_level_requested: aal_requested,
      piv_cac_requested: hspd12_requested,
      phishing_resistant_requested: phishing_resistant_requested,
      request_url: sp_request.url,
      request_id: sp_request.uuid,
      requested_attributes: sp_request.requested_attributes,
    }
  end

  def aal_requested
    Saml::Idp::Constants::AUTHN_CONTEXT_CLASSREF_TO_AAL[sp_request.aal]
  end

  def phishing_resistant_requested
    sp_request.aal == Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF ||
      sp_request.aal == Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
  end

  def hspd12_requested
    sp_request.aal == Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF ||
      sp_request.aal == Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF
  end

  def service_provider
    ServiceProvider.find_by(issuer: sp_request.issuer)
  end
end
