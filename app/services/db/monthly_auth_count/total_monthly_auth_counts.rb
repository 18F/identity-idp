module Db
  module MonthlyAuthCount
    class TotalMonthlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT issuer,year_month,SUM(auth_count) AS total
          FROM monthly_auth_counts
          GROUP BY issuer, year_month ORDER BY issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
