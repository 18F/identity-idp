module Db
  module MonthlySpAuthCount
    class SpMonthTotalAuthCounts
      def self.call(today, issuer, ial)
        sql = <<~SQL
          SELECT SUM(auth_count) AS total
          FROM monthly_sp_auth_counts
          WHERE issuer = '#{issuer}' AND ial=#{ial} AND year_month='#{today.strftime('%Y%m')}'
        SQL
        results = ActiveRecord::Base.connection.execute(sql)
        results.count.positive? ? results[0]['total'] || 0 : 0
      end
    end
  end
end
