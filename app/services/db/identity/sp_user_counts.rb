module Db
  module Identity
    class SpUserCounts
      # rubocop:disable Metrics/MethodLength
      def self.call
        sql = <<~SQL
          SELECT
            service_providers.issuer,
            total,
            ial1_total,
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
            count(user_id) AS total,
            count(user_id)-count(verified_at) AS ial1_total,
            count(verified_at) AS ial2_total
          FROM identities
          GROUP BY issuer ORDER BY issuer)
          AS TBL
          WHERE TBL.issuer = service_providers.issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
