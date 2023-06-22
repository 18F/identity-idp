module Db
  module Identity
    class SpUserCounts
      def self.by_issuer
        sql = <<~SQL
          SELECT
            service_provider AS issuer,
            count(user_id) AS total,
            count(user_id)-count(verified_at) AS ial1_total,
            count(verified_at) AS ial2_total,
            MAX(app_id) AS app_id
          FROM identities, service_providers
          WHERE identities.service_provider = service_providers.issuer
          GROUP BY identities.service_provider ORDER BY identities.service_provider
        SQL
        ActiveRecord::Base.connection.execute(sql).to_a
      end

      def self.with_issuer(issuer)
        sql = <<~SQL
          SELECT
            count(user_id) AS total,
            count(user_id)-count(verified_at) AS ial1_total,
            count(verified_at) AS ial2_total
          FROM identities
          WHERE identities.service_provider = ?
          LIMIT 1
        SQL

        query = ApplicationRecord.sanitize_sql_array([sql, issuer])
        ActiveRecord::Base.connection.execute(query).first
      end

      def self.overall
        sql = <<~SQL
          SELECT
            COUNT(*) AS num_users
          , by_user.is_ial2
          FROM (
            SELECT
              identities.user_id
            , BOOL_OR(identities.verified_at IS NOT NULL) AS is_ial2
            FROM identities
            GROUP BY identities.user_id
          ) by_user
          GROUP BY by_user.is_ial2
        SQL

        results = ActiveRecord::Base.connection.execute(sql).to_a

        ial1_total = results.find { |r| !r['is_ial2'] }&.fetch('num_users') || 0
        ial2_total = results.find { |r| r['is_ial2'] }&.fetch('num_users') || 0

        [
          {
            issuer: nil,
            app_id: nil,
            total: ial1_total + ial2_total,
            ial1_total:,
            ial2_total:,
          }.transform_keys(&:to_s),
        ]
      end
    end
  end
end
