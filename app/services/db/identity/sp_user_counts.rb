module Db
  module Identity
    class SpUserCounts
      def self.call
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
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
