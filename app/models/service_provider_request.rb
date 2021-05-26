class ServiceProviderRequest
  # WARNING - Modification of these params requires particular care
  # since these objects are serialized to/from Redis and may be present
  # upon deployment
  attr_accessor :uuid, :issuer, :url, :ial, :aal, :requested_attributes

  def initialize(
    uuid: nil,
    issuer: nil,
    url: nil,
    loa: nil,
    ial: nil,
    aal: nil,
    requested_attributes: []
  )
    @uuid = uuid
    @issuer = issuer
    @url = url
    @ial = ial || loa
    @aal = aal
    @requested_attributes = requested_attributes&.map(&:to_s)
    Rails.logger.info { 'Note: loa used to initialize ServiceProviderRequest' } if loa
  end

  def ==(other)
    to_json == other.to_json
  end

  # To be deleted once we've been deployed for a while and
  # the cached proxies are all using the new ial parameter
  def loa
    @ial
  end

  def loa=(val)
    @ial = val
  end
end
