module Reports
  class SpCostReportV2 < BaseReport
    REPORT_NAME = 'sp-cost-report-v2'.freeze
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
          issuer
          ial
          cost_type
          app_id
          count
        ]

        results.each do |row|
          csv << row.values_at('date', 'issuer', 'ial', 'cost_type', 'app_id', 'count')
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
          , sp_costs.issuer
          , sp_costs.ial
          , sp_costs.cost_type
          , MAX(app_id) AS app_id
          , COUNT(*) AS count
        FROM sp_costs
        JOIN service_providers ON sp_costs.issuer = service_providers.issuer
        WHERE
          %{start} <= sp_costs.created_at AND sp_costs.created_at <= %{finish}
        GROUP BY
            sp_costs.issuer
          , sp_costs.ial
          , sp_costs.cost_type
          , DATE(sp_costs.created_at)
        ORDER BY
            sp_costs.issuer
          , sp_costs.ial
          , sp_costs.cost_type
          , DATE(sp_costs.created_at)
      SQL

      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
