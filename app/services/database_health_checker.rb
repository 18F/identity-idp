# frozen_string_literal: true

module DatabaseHealthChecker
  module_function

  # @return [HealthCheckSummary]
  def check
    HealthCheckSummary.new(healthy: true, result: simple_query)
  rescue StandardError => err
    NewRelic::Agent.notice_error(err)
    HealthCheckSummary.new(healthy: false, result: err.message)
  end

  # @api private
  def simple_query
    ActiveRecord::Base.connection.select_values(sql_command)
  end

  # @api private
  def sql_command
    'SELECT 1'
  end
end
