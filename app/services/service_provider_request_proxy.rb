# Drop in replacement for ServiceProviderRequest. Moves us from Postgres to Redis
# To manage the migration and still respect in flight transactions code will default
# to checking the db if no redis object is available. Following release can remove db dependence.
# To migrate code simply replace ServiceProviderRequest with ServiceProviderRequestProxy
class ServiceProviderRequestProxy
  REDIS_KEY_PREFIX = 'spr:'.freeze
  REDIS_LAST_UUID_KEY = 'spr_last_uuid'.freeze
  DEFAULT_TTL_HOURS = 24

  def self.from_uuid(uuid)
    find_by(uuid: uuid) || NullServiceProviderRequest.new
  rescue ArgumentError # a null byte in the uuid will raise this
    NullServiceProviderRequest.new
  end

  def self.delete(request_id)
    return unless request_id
    REDIS_POOL.with do |client|
      client.delete(key(request_id))
      client.delete(REDIS_LAST_UUID_KEY) if Rails.env.test?
    end
  end

  def self.find_by(uuid:)
    return unless uuid
    obj = REDIS_POOL.with { |client| client.read(key(uuid)) }
    obj ? hash_to_spr(obj, uuid) : nil
  end

  def self.find_or_create_by(uuid:)
    obj = find_by(uuid: uuid)
    return obj if obj
    spr = ServiceProviderRequest.new(uuid: uuid, issuer: nil, url: nil, loa: nil,
                                     requested_attributes: nil)
    yield(spr)
    create(uuid: uuid,
           issuer: spr.issuer,
           url: spr.url,
           loa: spr.loa,
           requested_attributes: spr.requested_attributes)
  end

  def self.create(hash)
    uuid = hash[:uuid]
    obj = hash.slice(:issuer, :url, :loa, :requested_attributes)
    write(obj, uuid)
    hash_to_spr(obj, uuid)
  end

  def self.write(obj, uuid)
    REDIS_POOL.with do |client|
      client.write(key(uuid), obj)
      client.write(REDIS_LAST_UUID_KEY, uuid) if Rails.env.test?
    end
  end

  def self.create!(hash)
    create(hash)
  end

  # The .last uuid written is stored only in test mode to support existing specs
  def self.last
    REDIS_POOL.with do |client|
      uuid = client.read(REDIS_LAST_UUID_KEY)
      return nil unless uuid
      obj = client.read(key(uuid))
      hash_to_spr(obj, uuid)
    end
  end

  def self.key(uuid)
    REDIS_KEY_PREFIX + uuid
  end

  def self.flush
    REDIS_POOL.with(&:clear) if Rails.env.test?
  end

  def self.hash_to_spr(hash, uuid)
    ServiceProviderRequest.new(hash.merge(uuid: uuid))
  end
end
