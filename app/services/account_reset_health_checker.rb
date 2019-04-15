module AccountResetHealthChecker
  module_function

  Summary = Struct.new(:healthy, :result) do
    def as_json(*args)
      to_h.as_json(*args)
    end

    alias_method :healthy?, :healthy
  end

  # @return [Summary]
  def check
    rec = find_request_not_serviced_within_26_hours
    Summary.new(rec.nil?, rec)
  end

  # @api private
  def find_request_not_serviced_within_26_hours
    AccountResetRequest.where(
      sql, tvalue: Time.zone.now - Figaro.env.account_reset_wait_period_days.to_i.days - 2.hours
    ).order('requested_at ASC').first
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
