module Db
  module MonthlySpAuthCount
    class UniqueMonthlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT issuer,year_month,COUNT(*) AS total
          FROM monthly_sp_auth_counts
          GROUP BY issuer, ial, year_month ORDER BY issuer, ial, year_month
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
