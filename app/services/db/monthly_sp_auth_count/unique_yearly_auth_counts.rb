module Db
  module MonthlySpAuthCount
    class UniqueYearlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT issuer, MAX(app_id) AS app_id, year, COUNT(*) AS total
          FROM (
            SELECT monthly_sp_auth_counts.issuer, MAX(app_id) AS app_id, user_id,
                   monthly_sp_auth_counts.ial, LEFT(year_month, 4) AS year, COUNT(*)
            FROM monthly_sp_auth_counts, service_providers
            WHERE monthly_sp_auth_counts.issuer = service_providers.issuer
            GROUP BY monthly_sp_auth_counts.issuer, monthly_sp_auth_counts.ial,
                     year, user_id) AS tbl
          GROUP BY issuer, ial, year
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
