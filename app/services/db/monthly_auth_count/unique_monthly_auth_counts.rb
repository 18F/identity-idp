module Db
  module MonthlyAuthCount
    class UniqueMonthlyAuthCounts
      def self.call
        sql = <<~SQL
          SELECT issuer,year_month,COUNT(*) AS total
          FROM monthly_auth_counts
          GROUP BY issuer, year_month ORDER BY issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
