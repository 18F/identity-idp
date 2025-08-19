# frozen_string_literal: true

module AttemptsApi
  class FcmsTracker < Tracker
    include TrackerEvents
    attr_reader :current_user

    private

    def extra_attributes(event_type:)
      {
        agency_uuid: agency_uuid(event_type:),
        user_uuid: user&.uuid,
        user_id: user&.id,
        unique_session_id: user&.unique_session_id,
      }
    end

    def jwe(event)
      event.payload_json(issuer: sp.issuer)
    end

    def enabled?
      FeatureManagement.fcms_enabled?
    end

    def redis_client
      @redis_client ||= AttemptsApi::FcmsRedisClient.new
    end

    def public_key
      AppArtifacts.store.fcms_primary_public_key
    end
  end
end
