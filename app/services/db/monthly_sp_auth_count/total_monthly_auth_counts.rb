module Db
  module MonthlySpAuthCount
    class TotalMonthlyAuthCounts
      def self.call
        sql = <<-SQL
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
          GROUP BY
              sp_return_logs.issuer
            , sp_return_logs.ial
            , year_month
          ORDER BY
              sp_return_logs.issuer
            , sp_return_logs.ial
            , year_month
        SQL

        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
