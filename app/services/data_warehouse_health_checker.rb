# frozen_string_literal: true

module DataWarehouseHealthChecker
  module_function

  # @return [HealthCheckSummary]
  def check
    unless IdentityConfig.store.data_warehouse_enabled
      return HealthCheckSummary.new(
        healthy: false,
        result: 'Data warehouse is not enabled',
      )
    end

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
