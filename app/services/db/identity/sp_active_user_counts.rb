module Db
  module Identity
    class SpActiveUserCounts
      def self.by_issuer(start, finish = Time.zone.now)
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
        ActiveRecord::Base.connection.execute(sql).to_a
      end

      def self.overall(start, finish = Time.zone.now)
        params = {
          start: ActiveRecord::Base.connection.quote(start),
          finish: ActiveRecord::Base.connection.quote(finish),
        }
        sql = format(<<~SQL, params)
          SELECT
            COUNT(*) AS total
          , COUNT(by_user.is_ial2) AS ial2_active
          FROM (
            SELECT
              identities.user_id
            , BOOL_OR(last_ial2_authenticated_at BETWEEN %{start} AND %{finish}) AS is_ial2
            FROM identities
            WHERE
                 (last_ial1_authenticated_at BETWEEN %{start} AND %{finish})
              OR (last_ial2_authenticated_at BETWEEN %{start} AND %{finish})
            GROUP BY identities.user_id
          ) by_user
        SQL

        row = ActiveRecord::Base.connection.execute(sql).to_a.first

        total = row&.fetch('total') || 0
        total_ial2_active = row&.fetch('ial2_active') || 0
        total_ial1_active = total - total_ial2_active

        [
          {
            issuer: 'LOGIN_ALL',
            app_id: nil,
            total_ial1_active:,
            total_ial2_active:,
          }.transform_keys(&:to_s),
        ]
      end
    end
  end
end
