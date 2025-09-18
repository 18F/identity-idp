# frozen_string_literal: true

module FraudOps
  class Tracker < AttemptsApi::Tracker
    def initialize(session_id:, request:, user:, sp:, cookie_device_uuid:, sp_redirect_uri:)
      super(
        session_id: session_id,
        request: request,
        user: user,
        sp: sp,
        cookie_device_uuid: cookie_device_uuid,
        sp_redirect_uri: sp_redirect_uri,
        enabled_for_session: true,
      )
    end

    def track_event(event_type, metadata = {})
      return unless enabled?

      event = AttemptsApi::AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata(event_type:, metadata:),
      )

      redis_client.write_event(
        event_key: event.jti,
        jwe: jwe(event),
        timestamp: event.occurred_at,
      )

      event
    end

    private

    def extra_attributes(event_type: nil)
      {
        agency_uuid: agency_uuid(event_type:),
        user_uuid: user&.uuid,
        user_id: user&.id,
        unique_session_id: user&.unique_session_id,
      }
    end

    def enabled?
      IdentityConfig.store.fraud_ops_tracker_enabled
    end

    def public_key
      @public_key ||= OpenSSL::PKey::RSA.new(IdentityConfig.store.fraud_ops_public_key)
    end

    def redis_client
      @redis_client ||= FraudOps::RedisClient.new
    end

    def jwe(event)
      to_jwe(
        event: event,
        issuer: sp.issuer,
        public_key: public_key,
      )
    end

    def to_jwe(event:, issuer:, public_key:)
      jwk = JWT::JWK.new(public_key)

      JWE.encrypt(
        event.payload(issuer:).to_json,
        public_key,
        typ: 'secevent+jwe',
        zip: 'DEF',
        alg: 'RSA-OAEP',
        enc: 'A256GCM',
        kid: jwk.kid,
      )
    end
  end
end
