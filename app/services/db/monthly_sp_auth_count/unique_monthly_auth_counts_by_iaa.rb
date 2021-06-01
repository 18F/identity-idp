module Db
  module MonthlySpAuthCount
    module UniqueMonthlyAuthCountsByIaa
      extend Reports::QueryHelpers

      module_function

      # Aggregates a user metric at across issuers within the same IAA, during that IAA's
      # period of performance (between its start and end date), month-over-month, by IAL level
      # @param [String] iaa
      # @param [Symbol] aggregate (one of :sum, :unique, :new_unique)
      # @return [PG::Result, Array]
      def call(iaa:, aggregate:)
        date_range, issuers = iaa_parts(iaa)

        return [] if !date_range || !issuers

        full_months, partial_months = Reports::MonthHelper.months(date_range).
          partition do |month_range|
            Reports::MonthHelper.full_month?(month_range)
          end

        # The subqueries create a uniform representation of data:
        # - full months from monthly_sp_auth_counts
        # - partial months by aggregating sp_return_logs
        # The results are rows with [user_id, ial, auth_count, year_month]
        subquery = [
          full_month_subquery(issuers: issuers, full_months: full_months),
          *partial_month_subqueries(issuers: issuers, partial_months: partial_months),
        ].compact.join(' UNION ALL ')

        select_clause = case aggregate
        when :sum
          <<~SQL
            SUM(billing_month_logs.auth_count)::bigint AS total_auth_count
          SQL
        when :unique
          <<~SQL
            COUNT(DISTINCT billing_month_logs.user_id) AS unique_users
          SQL
        when :new_unique
          <<~SQL
            COUNT(DISTINCT billing_month_logs.user_id) AS new_unique_users
          SQL
        else
          raise "unknown aggregate=#{aggregate}"
        end

        where_clause = case aggregate
        when :new_unique
          # "new unique users" are users that we are seeing for the first
          # time this month, so this filters out users we have seen in a past
          # month by joining the subquery against itself
          <<~SQL
            NOT EXISTS (
              SELECT 1
              FROM subquery lookback_logs
              WHERE
                  lookback_logs.user_id = billing_month_logs.user_id
              AND lookback_logs.ial = billing_month_logs.ial
              AND lookback_logs.year_month < billing_month_logs.year_month
            )
          SQL
        else
          'TRUE'
        end

        params = {
          iaa_start_date: quote(date_range.begin),
          iaa_end_date: quote(date_range.end),
          iaa: quote(iaa),
          subquery: subquery,
          select_clause: select_clause,
          where_clause: where_clause,
        }

        sql = format(<<~SQL, params)
          WITH subquery AS (%{subquery})
          SELECT
            billing_month_logs.year_month
          , billing_month_logs.ial
          , %{iaa} AS iaa
          , %{iaa_start_date} AS iaa_start_date
          , %{iaa_end_date} AS iaa_end_date
          , %{select_clause}
          FROM
            subquery billing_month_logs
          WHERE
            %{where_clause}
          GROUP BY
            billing_month_logs.year_month
          , billing_month_logs.ial
        SQL

        ActiveRecord::Base.connection.execute(sql)
      end

      # @return [String]
      def full_month_subquery(issuers:, full_months:)
        return nil if full_months.blank?
        params = {
          issuers: issuers,
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
                  sp_return_logs.requested_at BETWEEN %{range_start} AND %{range_end}
              AND sp_return_logs.returned_at IS NOT NULL
              AND sp_return_logs.issuer IN %{issuers}
            GROUP BY
              sp_return_logs.user_id
            , sp_return_logs.ial
          SQL
        end
      end

      # @return [Array(Range<Date>, Array<String>)] date_range, issuers
      def iaa_parts(iaa)
        issuer_start_ends = ServiceProvider.
          where(iaa: iaa).
          pluck(:issuer, :iaa_start_date, :iaa_end_date)

        return [] if issuer_start_ends.empty?

        iaa_start_date, iaa_end_date = issuer_start_ends.flat_map do |_, start, finish|
          [start, finish]
        end.minmax

        issuers = issuer_start_ends.map { |issuer, *rest| issuer }.uniq

        [
          (iaa_start_date..iaa_end_date),
          issuers,
        ]
      end
    end
  end
end
