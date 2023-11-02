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
            identities.service_provider AS issuer
          , MAX(service_providers.app_id) AS app_id
          , COUNT(*) - SUM(
              CASE
              WHEN identities.last_ial2_authenticated_at BETWEEN %{start} AND %{finish} THEN 1
              ELSE 0
              END
            ) AS total_ial1_active
          , SUM(
              CASE
              WHEN identities.last_ial2_authenticated_at BETWEEN %{start} AND %{finish} THEN 1
              ELSE 0
              END
            ) AS total_ial2_active
          FROM identities
          JOIN service_providers ON service_providers.issuer = identities.service_provider
          WHERE
               (identities.last_ial1_authenticated_at BETWEEN %{start} AND %{finish})
            OR (identities.last_ial2_authenticated_at BETWEEN %{start} AND %{finish})
          GROUP BY identities.service_provider
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
            , BOOL_OR(identities.last_ial2_authenticated_at BETWEEN %{start} AND %{finish}) AS is_ial2
            FROM identities
            WHERE
                 (identities.last_ial1_authenticated_at BETWEEN %{start} AND %{finish})
              OR (identities.last_ial2_authenticated_at BETWEEN %{start} AND %{finish})
            GROUP BY identities.user_id
          ) by_user
        SQL

        row = ActiveRecord::Base.connection.execute(sql).to_a.first

        total = row&.fetch('total') || 0
        total_ial2_active = row&.fetch('ial2_active') || 0
        total_ial1_active = total - total_ial2_active

        [
          {
            issuer: nil,
            app_id: nil,
            total_ial1_active:,
            total_ial2_active:,
          }.transform_keys(&:to_s),
        ]
      end

      # The way we calculate our program APG (Agency Priority Goals) will count a user
      # twice if they are active at two separate SPs.
      #
      # Adds up results from by_issuer, users will be duplicated compared to by_issuer
      def self.overall_apg(start, finish = Time.zone.now)
        total_ial1_active = 0
        total_ial2_active = 0

        by_issuer(start, finish).each do |row|
          total_ial1_active += row['total_ial1_active']
          total_ial2_active += row['total_ial2_active']
        end

        [
          {
            issuer: nil,
            app_id: nil,
            total_ial1_active:,
            total_ial2_active:,
          }.transform_keys(&:to_s),
        ]
      end
    end
  end
end
