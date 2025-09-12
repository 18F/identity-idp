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

      extra_metadata =
        if metadata.has_key?(:failure_reason) &&
           (metadata[:failure_reason].blank? || metadata[:success].present?)
          metadata.except(:failure_reason)
        else
          metadata
        end

      event_metadata = {
        user_agent: request&.user_agent,
        unique_session_id: hashed_session_id,
        user_uuid: agency_uuid(event_type: event_type),
        device_id: cookie_device_uuid,
        user_ip_address: request&.remote_ip,
        application_url: sp_redirect_uri,
        language: user&.email_language || I18n.locale.to_s,
        client_port: CloudFrontHeaderParser.new(request).client_port,
        aws_region: IdentityConfig.store.aws_region,
        google_analytics_cookies: google_analytics_cookies(request),
      }

      event_metadata.merge!(extra_metadata)

      event = AttemptsApi::AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata,
      )

      jwe = to_jwe(
        event: event,
        issuer: sp.issuer,
        public_key: public_key,
      )

      redis_client.write_event(
        event_key: event.jti,
        jwe: jwe,
        timestamp: Time.zone.now,
      )
    end

    private

    def enabled?
      IdentityConfig.store.fraud_ops_tracker_enabled
    end

    def public_key
      @public_key ||= OpenSSL::PKey::RSA.new(IdentityConfig.store.fraud_ops_public_key)
    end

    def redis_client
      @redis_client ||= FraudOps::RedisClient.new
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
