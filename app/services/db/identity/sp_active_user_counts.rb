module Db
  module Identity
    class SpActiveUserCounts
      # rubocop:disable Metrics/MethodLength
      def self.call(start_date)
        sql = <<~SQL
          SELECT
            issuer,
            sum(total_ial1_active) AS total_ial1_active,
            sum(total_ial2_active) AS total_ial2_active
          FROM (
            (SELECT
              service_provider AS issuer,
              count(*) AS total_ial1_active,
              0 AS total_ial2_active
            FROM identities
            WHERE '#{start_date}' <= last_ial1_authenticated_at
            GROUP BY issuer ORDER BY issuer)
            UNION
            (SELECT
              service_provider AS issuer,
              0 AS total_ial1_active,
              count(*) AS total_ial2_active
            FROM identities
            WHERE '#{start_date}' <= last_ial2_authenticated_at
            GROUP BY issuer ORDER BY issuer)
          ) AS union_of_ial1_and_ial2_results
          GROUP BY ISSUER ORDER BY issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
