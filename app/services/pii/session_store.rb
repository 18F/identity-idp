# Provides a way to access already-decrypted and cached PII from the redis
# in an out-of-band fashion (using only the session UUID) instead of having access
# to the user_session from Devise/Warden
# Should only be used outside of a normal browser session (such as the OpenID Connect API)
# See Pii::Cacher for accessing PII inside of a normal browser session
module Pii
  class SessionStore
    attr_reader :session_uuid

    def initialize(session_uuid)
      @session_uuid = session_uuid
    end

    def ttl
      uuid = session_uuid
      session_store.instance_eval { redis.ttl(prefixed(uuid)) }
    end

    def load
      session = session_store.send(:load_session_from_redis, session_uuid) || {}

      pii_id = session.dig('warden.user.user.session', :pii_id)
      if pii_id
        redis_pii = EncryptedRedisStructStorage.load(pii_id, type: DecryptedPii)
        decrypted_pii = redis_pii.pii
        Pii::Attributes.new_from_json(decrypted_pii)
      else
        Pii::Attributes.new_from_json(session.dig('warden.user.user.session', :decrypted_pii))
      end
    end

    # @api private
    # Only used for convenience in tests
    # @param [Pii::Attributes] pii
    def put(pii, expiration = 5.minutes)
      redis_pii = DecryptedPii.new(
        id: SecureRandom.uuid,
        pii: pii.to_h.to_json,
      )

      EncryptedRedisStructStorage.store(redis_pii, expires_in: expiration.to_i)

      session_data = {
        'warden.user.user.session' => {
          pii_id: redis_pii.id
        },
      }

      session_store.
        send(:set_session, {}, session_uuid, session_data, expire_after: expiration.to_i)
    end

    # @api private
    # Only used for convenience in tests
    def destroy
      session_store.send(:destroy_session_from_sid, session_uuid)
    end

    private

    def session_store
      config = Rails.application.config
      config.session_store.new({}, config.session_options)
    end
  end
end
