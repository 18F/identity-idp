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
        return [] if !service_provider.iaa_start_date || !service_provider.iaa_end_date

        iaa_range = (service_provider.iaa_start_date..service_provider.iaa_end_date)

        full_months, partial_months = Reports::MonthHelper.months(iaa_range).
          partition do |month_range|
            Reports::MonthHelper.full_month?(month_range)
          end

        issuer = service_provider.issuer

        # The subqueries create a uniform representation of data:
        # - full months from monthly_sp_auth_counts
        # - partial months by aggregating sp_return_logs
        # The results are rows with [ial, auth_count, year_month, issuer, iaa, iaa start, iaa end]
        union_query = []
        if full_months.present?
          union_query << full_month_subquery(sp: service_provider, full_months: full_months)
        end
        union_query.
          concat(partial_month_subqueries(sp: service_provider, partial_months: partial_months))
        union_query = union_query.join(' UNION ALL ')

        ActiveRecord::Base.connection.execute(union_query)
      end


      # @return [String]
      def full_month_subquery(sp:, full_months:)
        params = {
          iaa: sp.iaa,
          issuer: sp.issuer,
          iaa_start_date: sp.iaa_start_date,
          iaa_end_date: sp.iaa_end_date,
          year_months: full_months.map { |r| r.begin.strftime('%Y%m') },
        }.transform_values { |value| quote(value) }

        full_month_subquery = format(<<~SQL, params)
          SELECT
            monthly_sp_auth_counts.year_month
          , monthly_sp_auth_counts.ial
          , SUM(monthly_sp_auth_counts.auth_count)::bigint AS total_auth_count
          , %{issuer} AS issuer
          , %{iaa} AS iaa
          , %{iaa_start_date} AS iaa_start_date
          , %{iaa_end_date} AS iaa_end_date
          FROM
            monthly_sp_auth_counts
          WHERE
                monthly_sp_auth_counts.issuer = %{issuer}
            AND monthly_sp_auth_counts.year_month IN %{year_months}
          GROUP BY
            monthly_sp_auth_counts.year_month
          , monthly_sp_auth_counts.ial
        SQL
      end

      # @return [Array<String>]
      def partial_month_subqueries(sp:, partial_months:)
        partial_months.map do |month_range|
          params = {
            iaa: sp.iaa,
            issuer: sp.issuer,
            iaa_start_date: sp.iaa_start_date,
            iaa_end_date: sp.iaa_end_date,
            range_start: month_range.begin,
            range_end: month_range.end,
            year_month: month_range.begin.strftime('%Y%m'),
          }.transform_values { |value| quote(value) }

          format(<<~SQL, params)
            SELECT
              %{year_month} AS year_month
            , sp_return_logs.ial
            , COUNT(sp_return_logs.id) AS auth_count
            , %{issuer} AS issuer
            , %{iaa} AS iaa
            , %{iaa_start_date} AS iaa_start_date
            , %{iaa_end_date} AS iaa_end_date
            FROM sp_return_logs
            WHERE
                  sp_return_logs.requested_at BETWEEN %{range_start} AND %{range_end}
              AND sp_return_logs.returned_at IS NOT NULL
              AND sp_return_logs.issuer = %{issuer}
            GROUP BY
              sp_return_logs.ial
          SQL
        end
      end
    end
  end
end
