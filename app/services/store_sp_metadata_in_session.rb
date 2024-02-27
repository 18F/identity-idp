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
    return nil if !sp_request.vtr && !sp_request.acr_values

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

  def ial2_value
    parsed_vot&.identity_proofing?
  end

  def piv_cac_requested_value
    parsed_vot&.hspd12?
  end

  def biometric_comparison_required_value
    parsed_vot&.biometric_comparison? || sp_request&.biometric_comparison_required
  end

  def update_session
    session[:sp] = {
      issuer: sp_request.issuer,
      request_url: sp_request.url,
      request_id: sp_request.uuid,
      requested_attributes: sp_request.requested_attributes,
      piv_cac_requested: piv_cac_requested_value,
      biometric_comparison_required: biometric_comparison_required_value,
      acr_values: sp_request.acr_values,
      vtr: sp_request.vtr,
    }
  end

  def service_provider
    return @service_provider if defined?(@service_provider)
    @service_provider = ServiceProvider.find_by(issuer: sp_request.issuer)
  end
end
