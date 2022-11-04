# Provides a wrapper for accessing the redis cache out-of-band (using only the
# session UUID) instead of having access to the user session from Devise/Warden.
# Should only used outside of a normal browser session (such as the OpenID
# Connect API or remote SAML Logout).

class OutOfBandSessionAccessor
  attr_reader :session_uuid

  def initialize(session_uuid)
    @session_uuid = session_uuid
  end

  def ttl
    uuid = session_uuid
    session_store.instance_eval { with_redis { |redis| redis.ttl(prefixed(uuid)) } }
  end

  def load
    session_store.send(:load_session_from_redis, session_uuid) || {}
  end

  def destroy
    session_store.send(:destroy_session_from_sid, session_uuid, drop: true)
  end

  # @api private
  # Only used for convenience in tests
  # @param [Pii::Attributes] pii
  def put(data, expiration = 5.minutes)
    session_data = {
      'warden.user.user.session' => data.to_h,
    }

    session_store.
      send(:set_session, {}, session_uuid, session_data, expire_after: expiration.to_i)
  end

  private

  def session_store
    @session_store ||= begin
      config = Rails.application.config
      config.session_store.new({}, config.session_options)
    end
  end
end
