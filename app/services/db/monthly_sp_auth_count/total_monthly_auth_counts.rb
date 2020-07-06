module Db
  module MonthlySpAuthCount
    class TotalMonthlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT monthly_sp_auth_counts.issuer,monthly_sp_auth_counts.ial,year_month,
                 SUM(auth_count) AS total, MAX(app_id) AS app_id
          FROM monthly_sp_auth_counts, service_providers
          WHERE monthly_sp_auth_counts.issuer = service_providers.issuer
          GROUP BY monthly_sp_auth_counts.issuer, monthly_sp_auth_counts.ial, year_month
          ORDER BY issuer, ial, year_month
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
