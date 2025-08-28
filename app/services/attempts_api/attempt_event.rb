# frozen_string_literal: true

module AttemptsApi
  class AttemptEvent
    attr_reader :jti, :iat, :event_type, :session_id, :occurred_at, :event_metadata, :language

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

    def to_jwe(public_key:, issuer:)
      jwk = JWT::JWK.new(public_key)

      JWE.encrypt(
        jwe_payload(payload_json: payload_json(issuer:)),
        public_key,
        typ: 'secevent+jwe',
        zip: 'DEF',
        alg: 'RSA-OAEP',
        enc: 'A256GCM',
        kid: jwk.kid,
      )
    end

    def self.from_jwe(jwe, private_key)
      decrypted_event = JWE.decrypt(jwe, private_key)

      if IdentityConfig.store.attempts_api_signing_enabled
        decrypted_event = JWT.decode(
          decrypted_event,
          SigningKey.public_key,
          true,
          { algorithm: 'ES256' },
        ).first
      end

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

    def payload(issuer:)
      {
        jti: jti,
        iat: iat,
        iss: Rails.application.routes.url_helpers.root_url,
        aud: issuer,
        events: {
          long_event_type => event_data,
        },
      }
    end

    def payload_json(issuer:)
      @payload_json ||= payload(issuer:).to_json
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

    def jwe_payload(payload_json:)
      if IdentityConfig.store.attempts_api_signing_enabled
        JWT.encode(payload_json, SigningKey.private_key, 'ES256')
      else
        payload_json
      end
    end

    def long_event_type
      dasherized_name = event_type.to_s.dasherize
      "https://schemas.login.gov/secevent/attempts-api/event-type/#{dasherized_name}"
    end

    module SigningKey
      class SigningKeyError < StandardError; end

      def self.private_key
        OpenSSL::PKey::EC.new(signing_key.private_to_pem)
      end

      def self.public_key
        OpenSSL::PKey::EC.new(signing_key.public_to_pem)
      end

      def self.signing_key
        raise SigningKeyError, 'Attempts API signing key is not configured' if
          IdentityConfig.store.attempts_api_signing_key.blank?

        OpenSSL::PKey::EC.new(IdentityConfig.store.attempts_api_signing_key)
      end
    end
  end
end
