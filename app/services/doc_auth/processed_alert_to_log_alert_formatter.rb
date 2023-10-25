# frozen_string_literal: true

module DocAuth
  class ProcessedAlertToLogAlertFormatter
    def log_alerts(alerts)
      log_alert_results = {}

      alerts.each do |key, key_alerts|
        key_alerts.each do |alert|
          alert_name_key = alert[:name].
            downcase.
            parameterize(separator: '_').
            to_sym

          side = alert[:side] || 'no_side'

          log_alert_results[alert_name_key] = {
            "#{side}": alert[:result],
          }
        end
      end

      log_alert_results
    end
  end
end
