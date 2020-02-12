class ServiceProviderRequest
  attr_accessor :uuid, :issuer, :url, :loa, :requested_attributes

  def initialize(attrs = {})
    @uuid = attrs[:uuid]
    @issuer = attrs[:issuer]
    @url = attrs[:url]
    @loa = attrs[:loa]
    @requested_attributes = attrs[:requested_attributes]&.map(&:to_s)
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
