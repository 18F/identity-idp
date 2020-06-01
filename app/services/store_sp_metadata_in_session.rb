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
      ial2: ial2_requested?,
      ial3: ial3_requested?,
      ialmax: ialmax_requested?,
      request_url: sp_request.url,
      request_id: sp_request.uuid,
      requested_attributes: sp_request.requested_attributes,
    }
  end

  def ialmax_requested?
    Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF == sp_request.ial
  end

  def ial2_requested?
    Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include? sp_request.ial
  end

  def ial3_requested?
    Saml::Idp::Constants::IAL3_AUTHN_CONTEXT_CLASSREF == sp_request.ial ||
      (ial2_requested? && service_provider&.liveness_checking_required)
  end

  def service_provider
    ServiceProvider.find_by(issuer: sp_request.issuer)
  end
end
