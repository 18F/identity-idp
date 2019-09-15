module Db
  module SpReturnLog
    class SuccessRateBySp
      def self.call
        sql = <<~SQL
          SELECT issuer, count(returned_at)::float/count(requested_at) as return_rate
          FROM sp_return_logs
          GROUP BY issuer ORDER BY issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
