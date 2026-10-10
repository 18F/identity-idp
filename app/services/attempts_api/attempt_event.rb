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

    # The event as plain JSON data, from which .from_json rebuilds it: for holding an event outside
    # the process, for example buffered in the session, before it is encrypted to a recipient.
    # Values are already in their JSON form (symbols as strings), so a reader sees the same data
    # whether or not the hash has been through a serializer in between. Nothing is dropped, so the
    # rebuilt event encrypts identically.
    # @return [Hash{String => Object}]
    def as_json(*)
      {
        'jti' => jti,
        'iat' => iat,
        'event_type' => event_type.to_s,
        'session_id' => session_id,
        'occurred_at' => occurred_at.to_f,
        'event_metadata' => JSON.parse((event_metadata || {}).to_json),
      }
    end

    # @param data [Hash] what #as_json produced, after a JSON round trip
    # @return [AttemptEvent]
    def self.from_json(data)
      data = data.stringify_keys
      new(
        jti: data['jti'],
        iat: data['iat'],
        event_type: data['event_type'],
        session_id: data['session_id'],
        occurred_at: Time.zone.at(data['occurred_at']),
        event_metadata: (data['event_metadata'] || {}).deep_symbolize_keys,
      )
    end

    def to_jwe(public_key:, issuer:)
      jwk = JWT::JWK.new(public_key)

      JWE.encrypt(
        signed_payload(issuer:),
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
        parsed_event = JWT.decode(
          decrypted_event,
          SigningKey.public_key,
          true,
          { algorithm: 'ES256' },
        ).first
      else
        parsed_event = JSON.parse(decrypted_event)
      end

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

    def signed_payload(issuer:)
      if IdentityConfig.store.attempts_api_signing_enabled
        JWT.encode(payload(issuer:), SigningKey.private_key, 'ES256')
      else
        payload(issuer:).to_json
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
