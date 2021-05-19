module Db
  module MonthlySpAuthCount
    module UniqueMonthlyAuthCountsByIaa
      module_function

      # Aggregates a user metric at across issuers within the same IAA, during that IAA's
      # period of performance (between its start and end date), month-over-month, by IAL level
      # @param [String] iaa
      # @param [Symbol] aggregate (one of :sum, :unique, :new_unique)
      # @return [PG::Result]
      def call(iaa:, aggregate:)
        date_range, issuers = iaa_parts(iaa)

        return [] if !date_range || !issuers

        full_months, partial_months = months(date_range).partition { |m| full_month?(m) }

        # The subqueries create a uniform representation of data:
        # - full months from monthly_sp_auth_counts
        # - partial months by aggregating sp_return_logs
        # The results are rows with [user_id, ial, iaa, year_month]
        subquery = [
          full_month_subquery(issuers: issuers, full_months: full_months),
          *partial_month_subqueries(issuers: issuers, partial_months: partial_months),
        ].join(' UNION ALL ')

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
            INNER JOIN service_providers
              ON sp_return_logs.issuer = service_providers.issuer
            WHERE
                  sp_return_logs.requested_at BETWEEN %{range_start} AND %{range_end}
              AND sp_return_logs.returned_at IS NOT NULL
              AND sp_return_logs.requested_at BETWEEN
                    service_providers.iaa_start_date AND service_providers.iaa_end_date
              AND service_providers.issuer IN %{issuers}
            GROUP BY
              sp_return_logs.user_id
            , sp_return_logs.ial
          SQL
        end
      end

      def quote(value)
        if value.is_a?(Array)
          "(#{value.map { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')})"
        else
          ActiveRecord::Base.connection.quote(value)
        end
      end

      # Takes a date range and breaks it into an array of ranges by month. The first and last items
      # may be partial months (ex starting in the middle and ending at the end) and the intermediate
      # items are always full months (1st to last of month)
      # @example
      #   months(Date.new(2021, 3, 15)..Date.new(2021, 5, 15))
      #   => [
      #     Date.new(2021, 3, 15)..Date.new(2021, 3, 31),
      #     Date.new(2021, 4, 1)..Date.new(2021, 4, 30),
      #     Date.new(2021, 5, 1)..Date.new(2021, 5, 15),
      #   ]
      # @param [Range<Date>] date_range
      # @return [Array<Range<Date>>]
      def months(date_range)
        results = []

        results << (date_range.begin..date_range.begin.end_of_month)

        current = date_range.begin.end_of_month + 1.day
        while current < date_range.end.beginning_of_month
          month_start = current.beginning_of_month
          month_end = current.end_of_month

          results << (month_start..month_end)

          current = month_end + 1.day
        end

        results << (date_range.end.beginning_of_month..date_range.end)

        results
      end

      def full_month?(date_range)
        date_range.begin == date_range.begin.beginning_of_month &&
          date_range.end == date_range.end.end_of_month
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
