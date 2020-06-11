class ServiceProviderRequest
  attr_accessor :uuid, :issuer, :url, :ial, :aal, :requested_attributes

  def initialize(uuid: nil, issuer: nil, url: nil, ial: nil, aal: nil, requested_attributes: [])
    @uuid = uuid
    @issuer = issuer
    @url = url
    @ial = ial
    @aal = aal
    @requested_attributes = requested_attributes&.map(&:to_s)
  end

  def ==(other)
    to_json == other.to_json
  end
end
