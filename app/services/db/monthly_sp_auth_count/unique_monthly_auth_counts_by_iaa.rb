module Db
  module MonthlySpAuthCount
    module UniqueMonthlyAuthCountsByIaa
      extend Reports::QueryHelpers

      module_function

      # @param [String] key label for billing (IAA + order number)
      # @param [Array<String>] issuers issuers for the iaa
      # @param [Date] start_date iaa start date
      # @param [Date] end_date iaa end date
      # @return [PG::Result, Array]
      def call(key:, issuers:, start_date:, end_date:)
        date_range = start_date...end_date

        return [] if !date_range || issuers.blank?

        full_months, partial_months = Reports::MonthHelper.months(date_range).
          partition do |month_range|
            Reports::MonthHelper.full_month?(month_range)
          end

        # The subqueries create a uniform representation of data:
        # - full months from monthly_sp_auth_counts
        # - partial months by aggregating sp_return_logs
        # The results are rows with [user_id, ial, auth_count, year_month]
        queries = [
          *full_month_subquery(issuers: issuers, full_months: full_months),
          *partial_month_subqueries(issuers: issuers, partial_months: partial_months),
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
              key: key,
              ial: ial,
              year_month: year_month,
              iaa_start_date: date_range.begin.to_s,
              iaa_end_date: date_range.end.to_s,
              total_auth_count: auth_count,
              unique_users: unique_users.count,
              new_unique_users: new_unique_users.count,
            }
          end
        end

        rows
      end

      # @return [String]
      def full_month_subquery(issuers:, full_months:)
        return if full_months.blank?
        params = {
          issuers: issuers,
          year_months: full_months.map { |r| r.begin.strftime('%Y%m') },
        }.transform_values { |value| quote(value) }

        format(<<~SQL, params)
          SELECT
            monthly_sp_auth_counts.user_id
          , monthly_sp_auth_counts.year_month
          , monthly_sp_auth_counts.auth_count
          , monthly_sp_auth_counts.ial
          FROM
            monthly_sp_auth_counts
          WHERE
                monthly_sp_auth_counts.issuer IN %{issuers}
            AND monthly_sp_auth_counts.year_month IN %{year_months}
        SQL
      end

      # @return [Array<String>]
      def partial_month_subqueries(issuers:, partial_months:)
        partial_months.map do |month_range|
          params = {
            range_start: month_range.begin,
            range_end: month_range.end,
            year_month: month_range.begin.strftime('%Y%m'),
            issuers: issuers,
          }.transform_values { |value| quote(value) }

          format(<<~SQL, params)
            SELECT
              sp_return_logs.user_id
            , %{year_month} AS year_month
            , COUNT(sp_return_logs.id) AS auth_count
            , sp_return_logs.ial
            FROM sp_return_logs
            WHERE
                  sp_return_logs.requested_at::date BETWEEN %{range_start} AND %{range_end}
              AND sp_return_logs.returned_at IS NOT NULL
              AND sp_return_logs.issuer IN %{issuers}
              AND sp_return_logs.billable = true
            GROUP BY
              sp_return_logs.user_id
            , sp_return_logs.ial
          SQL
        end
      end
    end
  end
end
