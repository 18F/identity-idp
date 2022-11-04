# Provides a way to access already-decrypted and cached PII from the redis
# in an out-of-band fashion (using only the session UUID) instead of having access
# to the user_session from Devise/Warden
# Should only be used outside of a normal browser session (such as the OpenID Connect API)
module X509
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
      X509::Attributes.new_from_json(session.dig('warden.user.user.session', :decrypted_x509))
    end

    # @api private
    # Only used for convenience in tests
    # @param [X509::Attributes] x509
    def put(piv_cert_info, expiration = 5.minutes)
      session_data = {
        'warden.user.user.session' => {
          decrypted_x509: piv_cert_info.to_h.to_json,
        },
      }

      session_store.
        send(:set_session, {}, session_uuid, session_data, expire_after: expiration.to_i)
    end

    private

    def session_store
      config = Rails.application.config
      config.session_store.new({}, config.session_options)
    end
  end
end
