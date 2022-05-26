module IrsAttemptsApi
  class EncryptedEventTokenBuilder
    attr_reader :jti, :iat, :event_type, :session_id, :occurred_at, :event_metadata

    def initialize(
      event_type:,
      session_id:,
      occurred_at:,
      event_metadata:,
      jti: SecureRandom.uuid,
      iat: Time.zone.now.to_i
    )
      @jti = jti
      @iat = iat
      @event_type = event_type
      @session_id = session_id
      @occurred_at = occurred_at
      @event_metadata = event_metadata
    end

    def build_event_token
      jwe = JWE.encrypt(
        security_event_token_data.to_json,
        event_data_encryption_key,
        typ: 'secevent+jwe',
        zip: 'DEF',
      )
      [jti, jwe]
    end

    private

    def security_event_token_data
      {
        jti: jti,
        iat: iat,
        iss: Rails.application.routes.url_helpers.root_url,
        aud: IdentityConfig.store.irs_attempt_api_audience,
        events: {
          long_event_type => event_data,
        },
      }
    end

    def event_data
      {
        'subject' => {
          'subject_type' => 'session',
          'session_id' => session_id,
        },
        'occurred_at' => occurred_at.to_i,
      }.merge(event_metadata || {})
    end

    def long_event_type
      "https://schemas.login.gov/secevent/irs-attempts-api/event-type/#{event_type.to_s.dasherize}"
    end

    def event_data_encryption_key
      decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
      OpenSSL::PKey::RSA.new(decoded_key_der)
    end
  end
end
