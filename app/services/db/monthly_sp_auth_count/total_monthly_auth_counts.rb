module Db
  module MonthlySpAuthCount
    class TotalMonthlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT issuer,ial,year_month,SUM(auth_count) AS total
          FROM monthly_sp_auth_counts
          GROUP BY issuer, ial, year_month ORDER BY issuer, ial, year_month
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
