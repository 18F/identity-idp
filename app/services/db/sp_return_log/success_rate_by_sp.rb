module Db
  module SpReturnLog
    class SuccessRateBySp
      def self.call
        sql = <<~SQL
          SELECT issuer, ial, MAX(app_id) AS app_id,
                 count(returned_at)::float/count(requested_at) as return_rate
          FROM sp_return_logs, service_providers
          WHERE sp_return_logs.issuer = service_providers.issuer
          GROUP BY sp_return_logs.issuer, sp_return_logs.ial
          ORDER BY issuer, ial
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
