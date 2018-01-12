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
    @sp_request ||= ServiceProviderRequest.from_uuid(request_id)
  end

  def update_session
    session[:sp] = {
      issuer: sp_request.issuer,
      loa3: loa3_requested?,
      request_url: sp_request.url,
      request_id: sp_request.uuid,
      requested_attributes: sp_request.requested_attributes,
    }
  end

  def loa3_requested?
    sp_request.loa == Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
  end
end
