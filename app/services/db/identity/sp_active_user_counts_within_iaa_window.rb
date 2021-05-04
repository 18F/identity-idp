module Db
  module Identity
    # Similar to SpActiveUserCounts, but it limits dates to within active IAA windows
    class SpActiveUserCountsWithinIaaWindow
      def self.call
        start_ends = ServiceProvider.select(:id, :issuer, :iaa_start_date, :iaa_end_date).
          where.not(iaa_start_date: nil).
          where.not(iaa_end_date: nil).
          group_by { |sp| [sp.iaa_start_date, sp.iaa_end_date] }

        start_ends.flat_map do |(iaa_start_date, iaa_end_date), service_providers|
          params = {
            iaa_start_date: quote(iaa_start_date),
            iaa_end_date: quote(iaa_end_date),
            issuers: service_providers.map { |sp| quote(sp.issuer) }.join(', ')
          }

          sql = format(<<-SQL, params)
            SELECT
              subq.issuer
            , MAX(subq.app_id) AS app_id
            , MAX(subq.iaa) AS iaa
            , MAX(subq.iaa_start_date) AS iaa_start_date
            , MAX(subq.iaa_end_date) AS iaa_end_date
            , SUM(
                CASE subq.ial
                WHEN 1 THEN 1
                ELSE 0
                END
              ) AS total_ial1_active
            , SUM (
                CASE subq.ial
                WHEN 2 THEN 1
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
                sp_return_logs.returned_at BETWEEN %{iaa_start_date} AND %{iaa_end_date}
                AND service_providers.issuer IN (%{issuers})
              GROUP BY
                service_providers.issuer
              , sp_return_logs.user_id
              , sp_return_logs.ial
            ) subq
            GROUP BY
              subq.issuer
          SQL

          ActiveRecord::Base.connection.execute(sql).to_a
        end
      end

      def self.quote(value)
        ActiveRecord::Base.connection.quote(value)
      end
    end
  end
end
