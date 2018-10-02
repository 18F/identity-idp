# Drop in replacement for ServiceProviderRequest. Moves us from Postgres to Redis
# To manage the migration and still respect in flight transactions code will default
# to checking the db if no redis object is available. Following release can remove db dependence.
# The .last uuid written is stored only in test mode to support existing specs
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

  def self.delete(guid)
    cache.delete(key(guid)) if guid
  end

  def self.find_by(uuid:)
    return unless uuid
    obj = cache.read(key(uuid))
    return hash_to_spr(obj, uuid) if obj
    ServiceProviderRequest.find_by(uuid: uuid)
  end

  def self.find_or_create_by(uuid:)
    obj = find_by(uuid: uuid)
    return obj if obj
    spr = ServiceProviderRequest.new
    spr.uuid = uuid
    yield(spr)
    create(uuid: uuid,
           issuer: spr.issuer,
           url: spr.url,
           loa: spr.loa,
           requested_attributes: spr.requested_attributes)
  end

  def self.create(hash)
    uuid = hash[:uuid]
    obj = {
      issuer: hash[:issuer],
      url: hash[:url],
      loa: hash[:loa],
      requested_attributes: hash[:requested_attributes],
    }
    cache.write(key(uuid), obj)
    cache.write(REDIS_LAST_UUID_KEY, uuid) if Rails.env.test?
    hash_to_spr(obj, uuid)
  end

  def self.last
    uuid = cache.read(REDIS_LAST_UUID_KEY)
    return unless uuid
    obj = cache.read(key(uuid))
    hash_to_spr(obj, uuid)
  end

  def self.key(uuid)
    REDIS_KEY_PREFIX + uuid
  end

  def self.cache
    env = Figaro.env
    ttl = env.service_provider_request_ttl_hours || DEFAULT_TTL_HOURS
    Readthis::Cache.new(
      expires_in: ttl.to_i.hours.to_i,
      redis: { url: env.redis_throttle_url, driver: :hiredis }
    )
  end

  def self.hash_to_spr(hash, uuid)
    spr = ServiceProviderRequest.new(hash)
    spr.uuid = uuid
    spr
  end
end
