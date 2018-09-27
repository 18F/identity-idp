class ServiceProviderRequestHandler
  def initialize(url:, session:, protocol_request:, protocol:)
    @url = url
    @session = session
    @protocol_request = protocol_request
    @protocol = protocol.new(protocol_request)
  end

  def call
    return if current_sp == sp_from_session

    ServiceProviderRequest.from_uuid(sp_session[:request_id]).delete
    ServiceProviderRequest.create!(attributes)

    StoreSpMetadataInSession.new(session: session, request_id: request_id).call
  end

  private

  attr_reader :url, :session, :protocol_request, :protocol

  def current_sp
    protocol.issuer
  end

  def sp_from_session
    ServiceProviderRequest.from_uuid(sp_session[:request_id]).issuer
  end

  def attributes
    {
      issuer: protocol.issuer,
      loa: protocol.loa,
      requested_attributes: protocol.requested_attributes,
      uuid: request_id,
      url: url,
    }
  end

  def request_id
    @request_id ||= SecureRandom.uuid
  end

  def sp_session
    session.fetch(:sp, {})
  end
end
