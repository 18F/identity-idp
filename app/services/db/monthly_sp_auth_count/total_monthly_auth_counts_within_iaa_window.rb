module Db
  module MonthlySpAuthCount
    # Similar to TotalMonthlyAuthCounts, but scopes authorizations to within
    # iaa_start_date and iaa_end_date
    # Also similar to UniqueMonthlyAuthCountsByIaa, but aggregates by issuer
    # instead of iaa
    module TotalMonthlyAuthCountsWithinIaaWindow
      extend Reports::QueryHelpers

      module_function

      # @return [PG::Result,Array]
      def call(service_provider)
        if !service_provider.iaa_start_date || !service_provider.iaa_end_date
          return []
        end

        iaa_range = (service_provider.iaa_start_date..service_provider.iaa_end_date)

        full_months, partial_months = Reports::MonthHelper.months(iaa_range).partition do |month_range|
          Reports::MonthHelper.full_month?(month_range)
        end

        # The subqueries create a uniform representation of data:
        # - full months from monthly_sp_auth_counts
        # - partial months by aggregating sp_return_logs
        # The results are rows with [user_id, ial, auth_count, year_month]
        subquery = [
          full_month_subquery(issuer: service_provider.issuer, full_months: full_months),
          *partial_month_subqueries(issuer: service_provider.issuer, partial_months: partial_months),
        ].join(' UNION ALL ')

        params = {
          iaa: quote(service_provider.iaa),
          iaa_start_date: quote(iaa_range.begin),
          iaa_end_date: quote(iaa_range.end),
          issuer: quote(service_provider.issuer),
          subquery: subquery,
        }

        sql = format(<<~SQL, params)
          SELECT
            billing_month_logs.year_month
          , billing_month_logs.ial
          , %{issuer} AS issuer
          , %{iaa} AS iaa
          , %{iaa_start_date} AS iaa_start_date
          , %{iaa_end_date} AS iaa_end_date
          , SUM(billing_month_logs.auth_count)::bigint AS total_auth_count
          FROM (%{subquery}) billing_month_logs
          GROUP BY
            billing_month_logs.year_month
          , billing_month_logs.ial
        SQL

        ActiveRecord::Base.connection.execute(sql)
      end


      # @return [String]
      def full_month_subquery(issuer:, full_months:)
        params = {
          issuer: issuer,
          year_months: full_months.map { |r| r.begin.strftime('%Y%m') },
        }.transform_values { |value| quote(value) }

        full_month_subquery = format(<<~SQL, params)
          SELECT
            monthly_sp_auth_counts.user_id
          , monthly_sp_auth_counts.year_month
          , monthly_sp_auth_counts.auth_count
          , monthly_sp_auth_counts.ial
          FROM
            monthly_sp_auth_counts
          WHERE
                monthly_sp_auth_counts.issuer = %{issuer}
            AND monthly_sp_auth_counts.year_month IN %{year_months}
        SQL
      end

      # @return [Array<String>]
      def partial_month_subqueries(issuer:, partial_months:)
        partial_months.map do |month_range|
          params = {
            range_start: month_range.begin,
            range_end: month_range.end,
            year_month: month_range.begin.strftime('%Y%m'),
            issuer: issuer,
          }.transform_values { |value| quote(value) }

          format(<<~SQL, params)
            SELECT
              sp_return_logs.user_id
            , %{year_month} AS year_month
            , COUNT(sp_return_logs.id) AS auth_count
            , sp_return_logs.ial
            FROM sp_return_logs
            WHERE
                  sp_return_logs.requested_at BETWEEN %{range_start} AND %{range_end}
              AND sp_return_logs.returned_at IS NOT NULL
              AND sp_return_logs.issuer = %{issuer}
            GROUP BY
              sp_return_logs.user_id
            , sp_return_logs.ial
          SQL
        end
      end
    end
  end
end
