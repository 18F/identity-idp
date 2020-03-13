module Db
  module MonthlySpAuthCount
    class UniqueYearlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT issuer, year, COUNT(*) AS total
          FROM (
            SELECT issuer, ial, LEFT(year_month, 4) AS year, user_id, COUNT(*)
            FROM monthly_sp_auth_counts
            GROUP BY issuer, ial, year, user_id) AS tbl
          GROUP BY issuer, ial, year
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
