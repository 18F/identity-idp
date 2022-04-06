module Db
  module MonthlySpAuthCount
    # Similar to TotalMonthlyAuthCounts, but scopes authorizations to within
    # iaa_start_date and iaa_end_date
    # Also similar to UniqueMonthlyAuthCountsByIaa, but aggregates by issuer
    # instead of iaa
    module TotalMonthlyAuthCountsWithinIaaWindow
      extend Reports::QueryHelpers

      module_function

      # @param [String] issuer
      # @param [String] iaa
      # @param [Date] iaa_start_date
      # @param [Date] iaa_end_date
      # @return [PG::Result,Array]
      def call(issuer:, iaa:, iaa_start_date:, iaa_end_date:)
        return [] if !iaa_start_date || !iaa_end_date

        iaa_range = (iaa_start_date..iaa_end_date)

        full_months, partial_months = Reports::MonthHelper.months(iaa_range).
          partition do |month_range|
            Reports::MonthHelper.full_month?(month_range)
          end

        # The subqueries create a uniform representation of data:
        # - full months from monthly_sp_auth_counts
        # - partial months by aggregating sp_return_logs
        # The results are rows with [user_id, ial, auth_count, year_month]
        queries = [
          *full_month_subquery(issuer: issuer, full_months: full_months),
          *partial_month_subqueries(issuer: issuer, partial_months: partial_months),
        ]

        ial_to_year_month_to_users = Hash.new do |ial_h, ial_k|
          ial_h[ial_k] = Hash.new { |ym_h, ym_k| ym_h[ym_k] = Multiset.new }
        end

        queries.each do |query|
          stream_query(query) do |row|
            user_id = row['user_id']
            year_month = row['year_month']
            auth_count = row['auth_count']
            ial = row['ial']

            ial_to_year_month_to_users[ial][year_month].add(user_id, auth_count)
          end
        end

        rows = []

        ial_to_year_month_to_users.each do |ial, year_month_to_users|
          prev_seen_users = Set.new

          year_months = year_month_to_users.keys.sort

          year_months.each do |year_month|
            year_month_users = year_month_to_users[year_month]

            auth_count = year_month_users.count
            unique_users = year_month_users.uniq.to_set

            new_unique_users = unique_users - prev_seen_users
            prev_seen_users |= unique_users

            rows << {
              issuer: issuer,
              iaa: iaa,
              ial: ial,
              year_month: year_month,
              iaa_start_date: iaa_range.begin.to_s,
              iaa_end_date: iaa_range.end.to_s,
              total_auth_count: auth_count,
              unique_users: unique_users.count,
              new_unique_users: new_unique_users.count,
            }
          end
        end

        rows
      end

      # @return [String]
      def full_month_subquery(issuer:, full_months:)
        return if full_months.blank?
        params = {
          issuer: issuer,
          year_months: full_months.map { |r| r.begin.strftime('%Y%m') },
        }.transform_values { |value| quote(value) }

        format(<<~SQL, params)
          SELECT
            monthly_sp_auth_counts.user_id
          , monthly_sp_auth_counts.year_month
          , monthly_sp_auth_counts.ial
          , SUM(monthly_sp_auth_counts.auth_count)::bigint AS auth_count
          FROM
            monthly_sp_auth_counts
          WHERE
                monthly_sp_auth_counts.issuer = %{issuer}
            AND monthly_sp_auth_counts.year_month IN %{year_months}
          GROUP BY
            monthly_sp_auth_counts.year_month
          , monthly_sp_auth_counts.ial
          , monthly_sp_auth_counts.user_id
        SQL
      end

      # @return [Array<String>]
      def partial_month_subqueries(issuer:, partial_months:)
        partial_months.map do |month_range|
          params = {
            range_start: month_range.begin,
            range_end: month_range.end,
            issuer: issuer,
            year_month: month_range.begin.strftime('%Y%m'),
          }.transform_values { |value| quote(value) }

          format(<<~SQL, params)
            SELECT
              sp_return_logs.user_id
            , %{year_month} AS year_month
            , sp_return_logs.ial
            , COUNT(sp_return_logs.id) AS auth_count
            FROM sp_return_logs
            WHERE
                  sp_return_logs.requested_at::date BETWEEN %{range_start} AND %{range_end}
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
