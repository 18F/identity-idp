require 'csv'

module Reports
  class TotalIal2CostsReport < BaseReport
    REPORT_NAME = 'total-ial2-costs'.freeze
    NUM_LOOKBACK_DAYS = 45

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(date)
      results = transaction_with_timeout { query(date) }

      save_report(REPORT_NAME, to_csv(results), extension: 'csv')
    end

    # @param [PG::Result]
    # @return [String]
    def to_csv(results)
      CSV.generate do |csv|
        csv << %w[
          date
          ial
          cost_type
          count
        ]

        results.each do |row|
          csv << row.values_at('date', 'ial', 'cost_type', 'count')
        end
      end
    end

    # @return [PG::Result]
    def query(date)
      finish = date.beginning_of_day
      start = (finish - NUM_LOOKBACK_DAYS.days).beginning_of_day

      params = {
        start: ActiveRecord::Base.connection.quote(start),
        finish: ActiveRecord::Base.connection.quote(finish),
      }

      sql = format(<<~SQL, params)
        SELECT
            DATE(sp_costs.created_at) AS date
          , sp_costs.ial
          , sp_costs.cost_type
          , COUNT(*) AS count
        FROM sp_costs
        WHERE
          %{start} <= sp_costs.created_at AND sp_costs.created_at <= %{finish}
          AND sp_costs.ial > 1
        GROUP BY
            sp_costs.ial
          , sp_costs.cost_type
          , DATE(sp_costs.created_at)
        ORDER BY
            sp_costs.ial
          , sp_costs.cost_type
          , DATE(sp_costs.created_at)
      SQL

      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
