module Db
  module Identity
    class SpUserQuotas
      def self.call(start_date)
        sql = <<~SQL
          SELECT
            service_providers.issuer,
            service_providers.app_id,
            ial2_total,
            CAST(
              (CASE WHEN ial2_quota IS NULL
              THEN 0
              ELSE ROUND(ial2_total * 100.0 / ial2_quota)
              END)
              AS INTEGER
            ) AS percent_ial2_quota
          FROM service_providers,
          (SELECT
            service_provider AS issuer,
            count(verified_at) AS ial2_total
          FROM identities
          WHERE '#{start_date}' <= verified_at
          GROUP BY issuer ORDER BY issuer)
          AS TBL
          WHERE TBL.issuer = service_providers.issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
