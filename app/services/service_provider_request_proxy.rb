# Drop in replacement for ServiceProviderRequest. Moves us from Postgres to Redis
# To manage the migration and still respect in flight transactions code will default
# to checking the db if no redis object is available. Following release can remove db dependence.
# To migrate code simply replace ServiceProviderRequest with ServiceProviderRequestProxy
class ServiceProviderRequestProxy
  REDIS_KEY_PREFIX = 'spr:'.freeze

  # This is used to support the .last method. That method is only used in the
  # test environment
  cattr_accessor :redis_last_uuid

  def self.from_uuid(uuid)
    return NullServiceProviderRequest.new if uuid.to_s.blank?
    find_by(uuid: uuid.to_s) || NullServiceProviderRequest.new
  rescue ArgumentError # a null byte in the uuid will raise this
    NullServiceProviderRequest.new
  end

  def self.delete(request_id)
    return unless request_id
    READTHIS_POOL.with do |client|
      client.delete(key(request_id))
      self.redis_last_uuid = nil if Rails.env.test?
    end
  end

  def self.find_by(uuid:)
    return if uuid.blank?
    obj = READTHIS_POOL.with { |client| client.read(key(uuid)) }
    obj ? hash_to_spr(obj, uuid) : nil
  end

  def self.find_or_create_by(uuid:)
    obj = find_by(uuid: uuid)
    return obj if obj
    spr = ServiceProviderRequest.new(
      uuid: uuid, issuer: nil, url: nil, ial: nil,
      aal: nil, requested_attributes: nil
    )
    yield(spr)
    create(
      uuid: uuid,
      issuer: spr.issuer,
      url: spr.url,
      ial: spr.ial,
      aal: spr.aal,
      requested_attributes: spr.requested_attributes,
    )
  end

  def self.create(hash)
    uuid = hash[:uuid]
    obj = hash.slice(:issuer, :url, :ial, :aal, :requested_attributes)
    write(obj, uuid)
    hash_to_spr(obj, uuid)
  end

  def self.write(obj, uuid)
    READTHIS_POOL.with do |client|
      client.write(key(uuid), obj)
      self.redis_last_uuid = uuid if Rails.env.test?
    end
  end

  def self.create!(hash)
    create(hash)
  end

  # The .last uuid written is stored only in test mode to support existing specs
  def self.last
    find_by(uuid: redis_last_uuid)
  end

  def self.key(uuid)
    REDIS_KEY_PREFIX + uuid
  end

  def self.flush
    READTHIS_POOL.with(&:clear) if Rails.env.test?
  end

  def self.hash_to_spr(hash, uuid)
    ServiceProviderRequest.new(hash.merge(uuid: uuid))
  end
end
