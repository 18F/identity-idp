module IrsAttemptsApi
  class Tracker
    attr_reader :session_id, :enabled_for_session, :request, :user, :sp, :device_fingerprint,
                :sp_request_uri

    def initialize(session_id:, request:, user:, sp:, device_fingerprint:,
                   sp_request_uri:, enabled_for_session:)
      @session_id = session_id # IRS session ID
      @request = request
      @user = user
      @sp = sp
      @device_fingerprint = device_fingerprint
      @sp_request_uri = sp_request_uri
      @enabled_for_session = enabled_for_session
    end

    def track_event(event_type, metadata = {})
      return unless enabled?

      event_metadata = {
        user_agent: request&.user_agent,
        unique_session_id: hashed_session_id,
        user_uuid: AgencyIdentityLinker.for(user: user, service_provider: sp)&.uuid,
        device_fingerprint: device_fingerprint,
        user_ip_address: request&.remote_ip,
        irs_application_url: sp_request_uri,
        client_port: CloudFrontHeaderParser.new(request).client_port,
      }.merge(metadata)

      event = AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata,
      )

      redis_client.write_event(
        event_key: event.event_key,
        jwe: event.to_jwe,
        timestamp: event.occurred_at,
      )

      event
    end

    include TrackerEvents

    private

    def hashed_session_id
      return nil unless user&.unique_session_id
      Digest::SHA1.hexdigest(user&.unique_session_id)
    end

    def enabled?
      IdentityConfig.store.irs_attempt_api_enabled && @enabled_for_session
    end

    def redis_client
      @redis_client ||= IrsAttemptsApi::RedisClient.new
    end
  end
end
