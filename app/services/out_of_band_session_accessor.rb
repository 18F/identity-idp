# Provides a wrapper for accessing the redis cache out-of-band (using only the
# session UUID) instead of having access to the user session from Devise/Warden.
# Should only used outside of a normal browser session (such as the OpenID
# Connect API or remote SAML Logout).
class OutOfBandSessionAccessor
  attr_reader :session_uuid

  PLACEHOLDER_REQUEST = ActionDispatch::TestRequest.create.freeze

  def initialize(session_uuid, session_store = nil)
    @session_uuid = session_uuid
    @session_store = session_store
  end

  def ttl
    uuid = Rack::Session::SessionId.new(session_uuid)
    session_store.instance_eval do
      with_redis_connection { |client| client.ttl(prefixed(uuid)) }
    end
  end

  # @return [Pii::Attributes, nil]
  def load_pii
    session = session_data.dig('warden.user.user.session')
    Pii::Cacher.new(nil, session).fetch if session
  end

  # @return [X509::Attributes]
  def load_x509
    X509::Attributes.new_from_json(session_data.dig('warden.user.user.session', :decrypted_x509))
  end

  def destroy
    session_store.send(
      :delete_session,
      PLACEHOLDER_REQUEST,
      Rack::Session::SessionId.new(session_uuid),
      drop: true,
    )
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

  # @api private
  # Only used for convenience in tests
  # @param [X509::Attributes] piv_cert_info
  def put_x509(piv_cert_info, expiration = 5.minutes)
    data = {
      decrypted_x509: piv_cert_info.to_h.to_json,
    }

    put(data, expiration)
  end

  # @api private
  # Only used for convenience in tests
  def exists?
    session_data.present?
  end

  private

  def put(data, expiration = 5.minutes)
    session_data = {
      'warden.user.user.session' => data.to_h,
    }

    session_store.send(
      :write_session,
      PLACEHOLDER_REQUEST,
      Rack::Session::SessionId.new(session_uuid),
      session_data,
      expire_after: expiration.to_i,
    )
  end

  # @return [Hash]
  def session_data
    return {} unless session_uuid
    uuid = Rack::Session::SessionId.new(session_uuid)
    @session_data ||= session_store.instance_eval do
      with_redis_connection do |client|
        load_session_from_redis(
          client,
          PLACEHOLDER_REQUEST,
          uuid,
        )
      end
    end || {}
  end

  def session_store
    @session_store ||= begin
      config = Rails.application.config
      config.session_store.new({}, config.session_options)
    end
  end
end
