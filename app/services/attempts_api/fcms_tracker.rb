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

    # TODO: Come up with something for when issuer is nil
    def issuer
      sp&.issuer
    end

    def jwe(event)
      if fcms_key_exists?
        super
      else
        event.payload_json(issuer:)
      end
    end

    def enabled?
      FeatureManagement.fcms_enabled?
    end

    def redis_client
      @redis_client ||= AttemptsApi::FcmsRedisClient.new
    end

    def public_key
      OpenSSL::PKey::RSA.new(fcms_config['keys'].first)
    end

    def fcms_key_exists?
      fcms_config.present? && fcms_config.key?('keys')
    end

    def fcms_config
      IdentityConfig.store.fcms_config
    end

    def key(timestamp, issuer)
      formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
      "fcms-events:#{sanitize(issuer)}:#{sanitize(formatted_time)}"
    end

    def sanitize(key_string)
      key_string.tr(':', '-')
    end
  end
end
