module AccountResetHealthChecker
  module_function

  # @return [HealthCheckSummary]
  def check
    unserviced_request_exists = request_not_serviced_within_wait_period_plus_2_hours?
    HealthCheckSummary.new(healthy: !unserviced_request_exists, result: unserviced_request_exists)
  end

  # @api private
  def request_not_serviced_within_wait_period_plus_2_hours?
    AccountResetRequest.exists?(
      [
        sql,
        tvalue: Time.zone.now - IdentityConfig.store.account_reset_wait_period_days.days - 2.hours,
      ],
    )
  end

  def sql
    <<~SQL
      cancelled_at IS NULL AND
      granted_at IS NULL AND
      requested_at < :tvalue AND
      request_token IS NOT NULL AND
      granted_token IS NULL
    SQL
  end
end
