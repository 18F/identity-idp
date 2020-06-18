class ServiceProviderRequest
  attr_accessor :uuid, :issuer, :url, :loa, :requested_attributes

  def initialize(uuid: nil, issuer: nil, url: nil, loa: nil, requested_attributes: [])
    @uuid = uuid
    @issuer = issuer
    @url = url
    @loa = loa
    @requested_attributes = requested_attributes&.map(&:to_s)
  end

  def ial
    @loa
  end

  def ial=(val)
    @loa = val
  end

  def ==(other)
    to_json == other.to_json
  end
end
