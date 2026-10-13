# frozen_string_literal: true

# Records single-use values in Redis and answers whether a value is being seen for the first
# time. The values are the `jti` of a DPoP proof or of a client assertion: a client may send each
# one once, so a captured request cannot be replayed while the original would still be accepted.
#
# Each value is recorded under who presented it (a key thumbprint, a client identifier), so one
# caller cannot burn another caller's values, and under a namespace per kind of value, so the
# same string presented as a proof and as a client assertion never collide. Callers record a
# value only after its signature verified, for the same reason.
module ReplayGuard
  # @param namespace [String] which kind of value, for example 'dpop:jti'
  # @param scope [String] who presented the value
  # @param value [String, nil] the single-use value; anything but a non-empty string is refused
  # @param ttl [Integer] seconds the value stays recorded, at least as long as a request carrying
  #   it could still be accepted
  # @return [Boolean] true the first time; false when the value was recorded within the ttl
  def self.first_use?(namespace:, scope:, value:, ttl:)
    return false unless value.is_a?(String) && value.present?

    REDIS_POOL.with do |client|
      client.set(key(namespace:, scope:, value:), '1', nx: true, ex: ttl)
    end ? true : false
  end

  # The Redis key for one value. Hashing keeps caller-supplied strings of any length or content
  # out of the key.
  def self.key(namespace:, scope:, value:)
    "#{namespace}:#{Digest::SHA256.hexdigest("#{scope}\n#{value}")}"
  end
end
