module IrsAttemptsApi
  class AttemptEvent
    attr_accessor :jti, :iat, :event_type, :session_id, :occurred_at, :event_metadata

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

    def to_jwe
      JWE.encrypt(
        payload.to_json,
        event_data_encryption_key,
        typ: 'secevent+jwe',
        zip: 'DEF',
        alg: 'RSA-OAEP',
        enc: 'A256GCM',
        kid: JWT::JWK.new(event_data_encryption_key).kid,
      )
    end

    def self.from_jwe(jwe, private_key)
      decrypted_event = JWE.decrypt(jwe, private_key)
      parsed_event = JSON.parse(decrypted_event)
      event_type = parsed_event['events'].keys.first.split('/').last
      event_data = parsed_event['events'].values.first
      jti = parsed_event['jti'].split(':').last
      AttemptEvent.new(
        jti: jti,
        iat: parsed_event['iat'],
        event_type: event_type,
        session_id: event_data['subject']['session_id'],
        occurred_at: Time.zone.at(event_data['occurred_at']),
        event_metadata: event_data.symbolize_keys.except(:subject, :occurred_at),
      )
    end

    def event_key
      "#{event_data_encryption_key_id}:#{jti}"
    end

    def payload
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

    private

    def event_data
      {
        'subject' => {
          'subject_type' => 'session',
          'session_id' => session_id,
        },
        'occurred_at' => occurred_at.to_f,
      }.merge(event_metadata || {})
    end

    def long_event_type
      dasherized_name = event_type.to_s.dasherize
      "https://schemas.login.gov/secevent/irs-attempts-api/event-type/#{dasherized_name}"
    end

    def event_data_encryption_key_id
      IdentityConfig.store.irs_attempt_api_public_key_id
    end

    def event_data_encryption_key
      @event_data_encryption_key ||= begin
        decoded_key_der = Base64.strict_decode64(IdentityConfig.store.irs_attempt_api_public_key)
        OpenSSL::PKey::RSA.new(decoded_key_der)
      end
    end
  end
end
