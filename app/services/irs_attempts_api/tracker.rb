module IrsAttemptsApi
  class Tracker
    attr_reader :session_id, :enabled_for_session, :request, :user, :sp, :cookie_device_uuid,
                :sp_request_uri, :analytics

    def initialize(session_id:, request:, user:, sp:, cookie_device_uuid:,
                   sp_request_uri:, enabled_for_session:, analytics:)
      @session_id = session_id # IRS session ID
      @request = request
      @user = user
      @sp = sp
      @cookie_device_uuid = cookie_device_uuid
      @sp_request_uri = sp_request_uri
      @enabled_for_session = enabled_for_session
      @analytics = analytics
    end

    def track_event(event_type, metadata = {})
      return unless enabled?

      return if ignore_idv_event?(event_type)

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
        irs_application_url: sp_request_uri,
        client_port: CloudFrontHeaderParser.new(request).client_port,
      }.merge(metadata)

      event = AttemptEvent.new(
        event_type: event_type,
        session_id: session_id,
        occurred_at: Time.zone.now,
        event_metadata: event_metadata,
      )

      if IdentityConfig.store.irs_attempt_api_payload_size_logging_enabled
        analytics.irs_attempts_api_event_metadata(
          event_type: event_type,
          unencrypted_payload_num_bytes: event.payload_json.bytesize,
          recorded: true,
        )
      end

      event
    end

    def parse_failure_reason(result)
      return result.to_h[:error_details] || result.errors.presence
    end

    include TrackerEvents

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
      IdentityConfig.store.irs_attempt_api_enabled && @enabled_for_session
    end

    def ignore_idv_event?(event_type)
      !IdentityConfig.store.irs_attempt_api_idv_events_enabled &&
        (event_type.to_s.starts_with? 'idv_')
    end
  end
end
