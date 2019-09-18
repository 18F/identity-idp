module Db
  module SpReturnLog
    class SuccessRateBySp
      def self.call
        sql = <<~SQL
          SELECT issuer, ial, count(returned_at)::float/count(requested_at) as return_rate
          FROM sp_return_logs
          GROUP BY issuer, ial ORDER BY issuer, ial
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
