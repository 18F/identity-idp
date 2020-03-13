module Db
  module Identity
    class SpUserCounts
      # rubocop:disable Metrics/MethodLength
      def self.call
        sql = <<~SQL
          SELECT
            service_provider AS issuer,
            count(user_id) AS total,
            count(user_id)-count(verified_at) AS ial1_total,
            count(verified_at) AS ial2_total
          FROM identities
          GROUP BY issuer ORDER BY issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
