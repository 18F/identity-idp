# Provides a way to access already-decrypted and cached PII from the redis
# in an out-of-band fashion (using only the session UUID) instead of having access
# to the user_session from Devise/Warden
# Should only be used outside of a normal browser session (such as the OpenID Connect API)
# See X509::Cacher for accessing PII inside of a normal browser session
module X509
  class SessionStore
    attr_reader :session_accessor

    delegate :ttl, :destroy, to: :session_accessor

    def initialize(session_uuid)
      @session_accessor = OutOfBandSessionAccessor.new(session_uuid)
    end

    # @return [X509::Attributes]
    def load
      session = session_accessor.load
      X509::Attributes.new_from_json(session.dig('warden.user.user.session', :decrypted_x509))
    end

    # @api private
    # Only used for convenience in tests
    # @param [X509::Attributes] piv_cert_info
    def put(piv_cert_info, expiration = 5.minutes)
      session_data = {
        decrypted_x509: piv_cert_info.to_h.to_json,
      }

      session_accessor.put(session_data, expiration)
    end
  end
end
