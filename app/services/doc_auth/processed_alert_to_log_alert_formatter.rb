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

          check_for_dupe!(log_alert_results, side, alert_name_key, alert[:result])

          log_alert_results[alert_name_key] = {
            "#{side}": alert[:result],
          }
        end
      end

      log_alert_results
    end

    private

    def check_for_dupe!(log_alert_results, side, alert_name_key, result)
      alert_value = log_alert_results.dig(alert_name_key, side.to_sym)
      if alert_value.present?
        Rails.logger.info("ALERT ALREADY HAS A VALUE: #{alert_value}, #{result}")
      end
    end
  end
end
