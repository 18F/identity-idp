class StoreSpMetadataInSession
  def initialize(session:, request_id:)
    @session = session
    @request_id = request_id
  end

  def call
    session[:sp] = {
      issuer: sp_request.issuer,
      loa3: loa3_requested?,
      request_url: sp_request.url,
      request_id: sp_request.uuid,
    }
  end

  private

  attr_reader :session, :request_id

  def sp_request
    @sp_request ||= ServiceProviderRequest.find_by(uuid: request_id)
  end

  def loa3_requested?
    sp_request.loa == Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
  end
end
