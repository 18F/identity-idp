module EventDisavowal
  class BuildDisavowedEventAnalyticsAttributes
    # rubocop:disable MethodLength,
    def self.call(event)
      return {} if event.blank?

      device = event.device
      {
        event_id: event.id,
        event_type: event.event_type,
        event_created_at: event.created_at,
        event_ip: event.ip,
        disavowed_device_user_agent: device&.user_agent,
        disavowed_device_last_ip: device&.last_ip,
        disavowed_device_last_used_at: device&.last_used_at,
      }
    end
    # rubocop:enable MethodLength
  end
end
