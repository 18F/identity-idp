class ServiceProviderRequestHandler
  def initialize(url:, session:, protocol_request:, protocol:)
    @url = url
    @session = session
    @protocol_request = protocol_request
    @protocol = protocol.new(protocol_request)
  end

  def call
    pull_request_id_from_current_sp_session_id

    delete_sp_request_if_session_has_matching_request_id
    ServiceProviderRequestProxy.create!(attributes)

    StoreSpMetadataInSession.new(session: session, request_id: request_id).call
  end

  private

  attr_reader :url, :session, :protocol_request, :protocol

  def ial
    uri = URI.parse(protocol.ial)
    ial_url = "#{uri.scheme}://#{uri.hostname}#{uri.path}"
    Saml::Idp::Constants::IAL2_AUTHN_CONTEXTS.include?(ial_url) ? 2 : 1
  end

  def current_sp
    protocol.issuer
  end

  def sp_stored_in_session
    return if sp_request_id.blank?
    ServiceProviderRequestProxy.from_uuid(sp_request_id).issuer
  end

  def pull_request_id_from_current_sp_session_id
    @request_id = sp_session[:request_id] if current_sp == sp_stored_in_session
  end

  def delete_sp_request_if_session_has_matching_request_id
    return if sp_request_id.blank?
    ServiceProviderRequestProxy.delete(sp_session[:request_id])
  end

  def attributes
    {
      issuer: protocol.issuer,
      ial: protocol.ial,
      aal: protocol.aal,
      requested_attributes: protocol.requested_attributes,
      uuid: request_id,
      url: url,
    }
  end

  def request_id
    @request_id ||= SecureRandom.uuid
  end

  def sp_request_id
    sp_session[:request_id]
  end

  def sp_session
    session.fetch(:sp, {})
  end
end
