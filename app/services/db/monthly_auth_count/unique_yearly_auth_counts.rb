module Db
  module MonthlyAuthCount
    class UniqueYearlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT issuer, year, COUNT(*) AS total
          FROM (
            SELECT issuer, LEFT(year_month, 4) AS year, user_id, COUNT(*)
            FROM monthly_auth_counts
            GROUP BY issuer, year, user_id) AS tbl
          GROUP BY issuer, year
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
