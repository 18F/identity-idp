module Db
  module Identity
    # Similar to SpActiveUserCounts, but it limits dates to within active IAA windows
    class SpActiveUserCountsWithinIaaWindow
      def self.call
        sql = <<-SQL
          SELECT
            subq.issuer
          , MAX(subq.app_id) AS app_id
          , MAX(subq.iaa) AS iaa
          , MAX(subq.iaa_start_date) AS iaa_start_date
          , MAX(subq.iaa_end_date) AS iaa_end_date
          , SUM(
              CASE subq.ial
              WHEN 1
              THEN 1
              ELSE 0
              END
            ) AS total_ial1_active
          , SUM (
              CASE subq.ial
              WHEN 2
              THEN 1
              ELSE 0
              END
            ) AS total_ial2_active
          FROM (
            SELECT
              service_providers.issuer
            , sp_return_logs.user_id
            , sp_return_logs.ial
            , MAX(service_providers.app_id) AS app_id
            , MAX(service_providers.iaa) AS iaa
            , MIN(service_providers.iaa_start_date) AS iaa_start_date
            , MAX(service_providers.iaa_end_date) AS iaa_end_date
            FROM
              service_providers
            JOIN
              sp_return_logs ON service_providers.issuer = sp_return_logs.issuer
            WHERE
              sp_return_logs.returned_at BETWEEN service_providers.iaa_start_date AND service_providers.iaa_end_date
            GROUP BY
              service_providers.issuer
            , sp_return_logs.user_id
            , sp_return_logs.ial
          ) subq
          GROUP BY
            subq.issuer
        SQL

        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
