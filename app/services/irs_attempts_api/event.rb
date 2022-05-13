module IrsAttemptsApi
  Event = Struct.new(:jti, :iat, :event_type, :encrypted_event_data, keyword_init: true) do

    def self.build(event_type:, session_id:, occurred_at:, event_metadata:)
      jti = SecureRandom.uuid()
      iat = Time.now.to_i
      encrypted_event_data = encrypt_event_data(
        session_id: session_id,
        occurred_at: occurred_at,
        event_metadata: event_metadata,
      )
      self.new(
        jti: jti, iat: iat, event_type: event_type, encrypted_event_data: encrypted_event_data
      )
    end

    def security_event_token_data
      @security_event_token_data ||= {
        'iss' => Rails.application.routes.url_helpers.root_url,
        'jti' => jti,
        'iat' => iat,
        'aud' => IdentityConfig.store.irs_attempt_api_audience,
        'events' => events,
      }
    end

    def jwt
      JWT.encode(
        security_event_token_data,
        AppArtifacts.store.oidc_private_key,
        'RS256',
        typ: 'secevent+jwt',
      )
    end

    private

    def events
      { long_event_type => encrypted_event_data }
    end

    def long_event_type
      "https://schemas.login.gov/secevent/irs-attempts-api/event-type/#{event_type.to_s.dasherize}"
    end

    def self.encrypt_event_data(session_id:, occurred_at:, event_metadata:)
      event_data = {
        'subject' => {
          'subject_type' => 'session',
          'session_id' => session_id,
        },
        'occurred_at' => occurred_at.to_i,
      }.merge(event_metadata || {})

      Base64.strict_encode64(
        event_data_encryption_key.public_encrypt(event_data.to_json)
      )
    end

    def self.event_data_encryption_key
      decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
      OpenSSL::PKey::RSA.new(decoded_key_der)
    end
  end
end
