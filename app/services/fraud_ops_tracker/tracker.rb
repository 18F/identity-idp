# frozen_string_literal: true

module FraudOpsTracker
  class Tracker < AttemptsApi::Tracker
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
      if fraudops_key_exists?
        super
      # TODO: Remove this and add handling for missing key once encryption testing is finalized
      else
        event.payload_json(issuer:)
      end
    end

    def enabled?
      FeatureManagement.fraudops_enabled?
    end

    def redis_client
      @redis_client ||= RedisClient.new
    end

    def public_key
      OpenSSL::PKey::RSA.new(fraudops_config['keys'].first)
    end

    def fraudops_key_exists?
      fraudops_config.present? && fraudops_config.key?('keys')
    end

    def fraudops_config
      IdentityConfig.store.fraudops_config
    end

    def key(timestamp, issuer)
      formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
      "fraudops-events:#{sanitize(issuer)}:#{sanitize(formatted_time)}"
    end

    def sanitize(key_string)
      key_string.tr(':', '-')
    end
  end
end
