module DocAuth
  class ProcessedAlertToLogAlertFormatter
    def get_alert_result(log_alert_results, side, alert_name_key, result)
      if log_alert_results.dig(alert_name_key, side.to_sym).present?
        alert_value = log_alert_results[alert_name_key][side.to_sym]
        Rails.logger.
          info("ALERT ALREADY HAS A VALUE: #{alert_value}, #{result}")
      end
      result
    end

    def log_alerts(alerts)
      log_alert_results = {}

      alerts.keys.each do |key|
        alerts[key.to_sym].each do |alert|
          alert_name_key = alert[:name].
                           downcase.
                           parameterize(separator: '_').to_sym
          side = alert[:side] || 'no_side'

          log_alert_results[alert_name_key] =
            { "#{side}": get_alert_result(
              log_alert_results,
              side,
              alert_name_key,
              alert[:result],
            ) }
        end
      end
      log_alert_results
    end
  end
end
