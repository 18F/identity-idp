class StoreSpMetadataInSession
  def initialize(session:, request_id:)
    @session = session
    @request_id = request_id
  end

  def call(service_provider_request: nil, requested_service_provider: nil)
    @sp_request = service_provider_request if service_provider_request
    @service_provider = requested_service_provider

    return if sp_request.is_a?(NullServiceProviderRequest)
    update_session
  end

  private

  attr_reader :session, :request_id

  def parsed_vot
    @parsed_vot ||= AuthnContextResolver.new(
      service_provider: service_provider,
      vtr: sp_request.vtr,
      acr_values: sp_request.acr_values,
    ).resolve
  end

  def ial_context
    @ial_context ||= IalContext.new(ial: sp_request.ial, service_provider: service_provider)
  end

  def sp_request
    @sp_request ||= ServiceProviderRequestProxy.from_uuid(request_id)
  end

  def ial_value
    if parsed_vot.ialmax?
      0
    elsif parsed_vot.identity_proofing?
      2
    else
      1
    end
  end

  def ial2_value
    parsed_vot.identity_proofing?
  end

  def ialmax_value
    parsed_vot.ialmax?
  end

  def aal_level_requested_value
    if parsed_vot.phishing_resistant?
      3
    elsif parsed_vot.aal2?
      2
    else
      1
    end
  end

  def piv_cac_requested_value
    parsed_vot.hspd12?
  end

  def phishing_resistant_value
    parsed_vot.phishing_resistant?
  end

  def biometric_comparison_required_value
    parsed_vot.biometric_comparison?
  end

  def update_session
    session[:sp] = {
      issuer: sp_request.issuer,
      request_url: sp_request.url,
      request_id: sp_request.uuid,
      requested_attributes: sp_request.requested_attributes,
    }

    if IdentityConfig.store.use_vot_in_sp_requests
      session[:sp].merge!(
        {
          ial: ial_value,
          ial2: ial2_value,
          ialmax: ialmax_value,
          aal_level_requested: aal_level_requested_value,
          piv_cac_requested: piv_cac_requested_value,
          phishing_resistant_requested: phishing_resistant_value,
          biometric_comparison_required: biometric_comparison_required_value,
        },
      )
    else
      session[:sp].merge!(
        {
          ial: ial_context.ial,
          ial2: ial_context.ial2_requested?,
          ialmax: ial_context.ialmax_requested?,
          aal_level_requested: aal_requested,
          piv_cac_requested: hspd12_requested,
          phishing_resistant_requested: phishing_resistant_requested,
          biometric_comparison_required: sp_request.biometric_comparison_required,
        },
      )
    end
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
    return @service_provider if defined?(@service_provider)
    @service_provider = ServiceProvider.find_by(issuer: sp_request.issuer)
  end
end
