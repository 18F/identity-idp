module IrsAttemptsApi
  class Tracker
    attr_reader :enabled_for_session, :request, :user, :sp, :cookie_device_uuid,
                :sp_request_uri, :analytics

    def initialize(request:, user:, sp:, cookie_device_uuid:,
                   sp_request_uri:, enabled_for_session:, analytics:)
      @request = request
      @user = user
      @sp = sp
      @cookie_device_uuid = cookie_device_uuid
      @sp_request_uri = sp_request_uri
      @enabled_for_session = enabled_for_session
      @analytics = analytics
    end

    def track_event(event_type, metadata = {})
    end

    def parse_failure_reason(result)
      return result.to_h[:error_details] || result.errors.presence
    end

    include TrackerEvents
  end
end
