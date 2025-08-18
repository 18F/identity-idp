# frozen_string_literal: true

module AttemptsApi
  class FcmsTracker < Tracker
    include TrackerEvents
    attr_reader :current_user

    private

    def build_event_metadata(event_type, metadata)
      extra_metadata =
        if metadata.has_key?(:failure_reason) &&
           (metadata[:failure_reason].blank? || metadata[:success].present?)
          metadata.except(:failure_reason)
        else
          metadata
        end

      # Custom Metadata for FCMS
      event_metadata = {
        user_uuid: user&.uuid,
        user_id: user&.id,
        unique_session_id: user&.unique_session_id,
        agency_uuid: agency_uuid(event_type: event_type),
        device_id: cookie_device_uuid,
        user_ip_address: request&.remote_ip,
        user_agent: request&.user_agent,
        application_url: sp_request_uri,
        language: user&.email_language || I18n.locale.to_s,
        client_port: CloudFrontHeaderParser.new(request).client_port,
        aws_region: IdentityConfig.store.aws_region,
        google_analytics_cookies: google_analytics_cookies(request),
      }

      event_metadata.merge!(extra_metadata)
    end

    def build_jwe(event)
      event.payload_json(issuer: sp.issuer)
    end

    def enabled?
      FeatureManagement.fcms_enabled?
    end

    def redis_client
      @redis_client ||= AttemptsApi::FcmsRedisClient.new
    end
  end
end
