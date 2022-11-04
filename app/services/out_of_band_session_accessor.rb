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
    session_store.instance_eval { redis.ttl(prefixed(uuid)) }
  end

  # @return [Pii::Attributes, nil]
  def load_pii
    session = load.dig('warden.user.user.session')
    Pii::Cacher.new(nil, session).fetch if session
  end

  # @return [X509::Attributes]
  def load_x509
    X509::Attributes.new_from_json(load.dig('warden.user.user.session', :decrypted_x509))
  end

  def destroy
    session_store.send(:destroy_session_from_sid, session_uuid, drop: true)
  end

  # @api private
  # Only used for convenience in tests
  # @param [Pii::Attributes] pii
  def put_pii(pii, expiration = 5.minutes)
    data = {
      decrypted_pii: pii.to_h.to_json,
    }

    put(data, expiration)
  end

  # @param [X509::Attributes] piv_cert_info
  def put_x509(piv_cert_info, expiration = 5.minutes)
    data = {
      decrypted_x509: piv_cert_info.to_h.to_json,
    }

    put(data, expiration)
  end

  private

  def put(data, expiration = 5.minutes)
    session_data = {
      'warden.user.user.session' => data.to_h,
    }

    session_store.
      send(:set_session, {}, session_uuid, session_data, expire_after: expiration.to_i)
  end

  # @return [Hash]
  def load
    session_store.send(:load_session_from_redis, session_uuid) || {}
  end

  def session_store
    @session_store ||= begin
      config = Rails.application.config
      config.session_store.new({}, config.session_options)
    end
  end
end
