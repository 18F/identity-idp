module Db
  module Identity
    class SpActiveUserCounts
      def self.call(start, finish = Time.zone.now)
        params = {
          start: ActiveRecord::Base.connection.quote(start),
          finish: ActiveRecord::Base.connection.quote(finish),
        }
        sql = format(<<~SQL, params)
          SELECT
            service_providers.issuer,
            MAX(app_id) AS app_id,
            CAST(SUM(total_ial1_active) AS INTEGER) AS total_ial1_active,
            CAST(SUM(total_ial2_active) AS INTEGER) AS total_ial2_active
          FROM (
            (SELECT
              service_provider AS issuer,
              count(*) AS total_ial1_active,
              0 AS total_ial2_active
            FROM identities
            WHERE %{start} <= last_ial1_authenticated_at AND last_ial1_authenticated_at <= %{finish}
            GROUP BY issuer ORDER BY issuer)
            UNION
            (SELECT
              service_provider AS issuer,
              0 AS total_ial1_active,
              count(*) AS total_ial2_active
            FROM identities
            WHERE %{start} <= last_ial2_authenticated_at AND last_ial2_authenticated_at <= %{finish}
            GROUP BY issuer ORDER BY issuer)
          ) AS union_of_ial1_and_ial2_results, service_providers
          WHERE union_of_ial1_and_ial2_results.issuer = service_providers.issuer
          GROUP BY service_providers.issuer ORDER BY service_providers.issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
