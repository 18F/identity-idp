module Db
  module MonthlySpAuthCount
    class TotalMonthlyAuthCounts
      # @return [Array<Hash>]
      def self.call
        oldest = ::SpReturnLog.first&.requested_at&.to_date&.beginning_of_month
        newest = ::SpReturnLog.last&.requested_at&.to_date&.end_of_month

        return [] if !oldest || !newest

        Reports::MonthHelper.months(oldest..newest).flat_map do |month_range|
          query_month(month_range)
        end
      end

      # @param [Range<Date>]
      # @return [Array<Hash>]
      def self.query_month(month_range)
        params = {
          month_start: month_range.begin,
          month_end: month_range.end,
        }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }

        sql = format(<<-SQL, params)
          SELECT
              sp_return_logs.issuer
            , sp_return_logs.ial
            , to_char(sp_return_logs.requested_at, 'YYYYMM') AS year_month
            , COUNT(sp_return_logs.id) AS total
            , MAX(service_providers.app_id) AS app_id
          FROM sp_return_logs
          JOIN service_providers ON service_providers.issuer = sp_return_logs.issuer
          WHERE
                sp_return_logs.returned_at IS NOT NULL
            AND sp_return_logs.billable = true
            AND %{month_start}::date <= sp_return_logs.requested_at::date
            AND sp_return_logs.requested_at::date <= %{month_end}::date
          GROUP BY
              sp_return_logs.issuer
            , sp_return_logs.ial
            , year_month
          ORDER BY
              sp_return_logs.issuer
            , sp_return_logs.ial
            , year_month
        SQL

        Reports::BaseReport.transaction_with_timeout do
          ActiveRecord::Base.connection.execute(sql)
        end.to_a
      end
    end
  end
end
