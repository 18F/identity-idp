# Provides a way to access already-decrypted and cached PII from the redis
# in an out-of-band fashion (using only the session UUID) instead of having access
# to the user_session from Devise/Warden
# Should only be used outside of a normal browser session (such as the OpenID Connect API)
# See Pii::Cacher for accessing PII inside of a normal browser session
module Pii
  class SessionStore
    attr_reader :session_accessor

    delegate :ttl, :destroy, to: :session_accessor

    def initialize(session_uuid)
      @session_accessor = OutOfBandSessionAccessor.new(session_uuid)
    end

    def load
      session = session_accessor.load

      Pii::Cacher.new(nil, session.dig('warden.user.user.session')).fetch
    end

    # @api private
    # Only used for convenience in tests
    # @param [Pii::Attributes] pii
    def put(pii, expiration = 5.minutes)
      session_data = {
        decrypted_pii: pii.to_h.to_json,
      }

      session_accessor.put(session_data, expiration)
    end
  end
end
