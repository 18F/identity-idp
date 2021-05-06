module Db
  module Identity
    # Similar to SpActiveUserCounts, but it limits dates to within active IAA windows
    class SpActiveUserCountsWithinIaaWindow
      def self.call
        service_providers = ServiceProvider.arel_table
        identities = ServiceProviderIdentity.arel_table

        sql = <<~SQL
          SELECT
            service_providers.issuer
          , MAX(service_providers.app_id) AS app_id
          , MAX(service_providers.iaa) AS iaa
          , MIN(service_providers.iaa_start_date) AS iaa_start_date
          , MAX(service_providers.iaa_end_date) AS iaa_end_date
          , SUM(
              CASE
              WHEN identities.last_ial1_authenticated_at >= service_providers.iaa_start_date THEN 1
              ELSE 0
              END
            ) AS total_ial1_active
          , SUM(
              CASE
              WHEN identities.last_ial2_authenticated_at >= service_providers.iaa_start_date THEN 1
              ELSE 0
              END
            ) AS total_ial2_active
          FROM service_providers
         INNER JOIN identities ON identities.service_provider = service_providers.issuer
          WHERE
          (
               identities.last_ial1_authenticated_at >= service_providers.iaa_start_date
            OR identities.last_ial2_authenticated_at >= service_providers.iaa_start_date
          )
          GROUP BY service_providers.issuer
          ORDER BY service_providers.issuer ASC
        SQL

        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
