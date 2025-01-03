# frozen_string_literal: true

module AttemptsApi
  class Tracker
    attr_reader :session_id, :enabled_for_session, :request, :user, :sp, :cookie_device_uuid,
                :sp_request_uri, :analytics

    def initialize(session_id:, request:, user:, sp:, cookie_device_uuid:,
                   sp_request_uri:, enabled_for_session:, analytics:)
      @session_id = session_id
      @request = request
      @user = user
      @sp = sp
      @cookie_device_uuid = cookie_device_uuid
      @sp_request_uri = sp_request_uri
      @enabled_for_session = enabled_for_session
      @analytics = analytics
    end
    include TrackerEvents

    def track_event(event_type, metadata = {})
      return unless enabled?

      if metadata.has_key?(:failure_reason) &&
         (metadata[:failure_reason].blank? ||
          metadata[:success].present?)
        metadata.delete(:failure_reason)
      end

      event_metadata = {
        user_agent: request&.user_agent,
        unique_session_id: hashed_session_id,
        user_uuid: sp && AgencyIdentityLinker.for(user: user, service_provider: sp)&.uuid,
        device_fingerprint: hashed_cookie_device_uuid,
        user_ip_address: request&.remote_ip,
        application_url: sp_request_uri,
        client_port: CloudFrontHeaderParser.new(request).client_port,
      }

      event_metadata.merge!(metadata)

      event = AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata,
      )

      jwe = event.to_jwe(
        issuer: sp.issuer,
        public_key: sp.ssl_certs.first.public_key,
      )

      redis_client.write_event(
        event_key: event.jti,
        jwe: jwe,
        timestamp: event.occurred_at,
        issuer: sp.issuer,
      )

      event
    end

    def parse_failure_reason(result)
      return result.to_h[:error_details] || result.errors.presence
    end

    private

    def hashed_session_id
      return nil unless user&.unique_session_id
      Digest::SHA1.hexdigest(user&.unique_session_id)
    end

    def hashed_cookie_device_uuid
      return nil unless cookie_device_uuid
      Digest::SHA1.hexdigest(cookie_device_uuid)
    end

    def enabled?
      IdentityConfig.store.attempts_api_enabled && @enabled_for_session
    end

    def redis_client
      @redis_client ||= AttemptsApi::RedisClient.new
    end
  end
end
