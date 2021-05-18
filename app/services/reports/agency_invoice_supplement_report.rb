module Reports
  class AgencyInvoiceSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-supplemement-report'.freeze

    def call
      iaa_range_issuers.map do |iaa_parts|
        iaa_query(iaa_parts)
      end
    end

    def full_month_subquery(iaa_parts, full_months)
      params = {
        iaa: iaa_parts.iaa,
        issuers: iaa_parts.issuers,
        year_months: full_months.map { |r| r.begin.strftime('%Y%m') }
      }.transform_values { |value| quote(value) }

      full_month_subquery = format(<<-SQL, params)
        SELECT
          monthly_sp_auth_counts.user_id
        , monthly_sp_auth_counts.year_month
        , monthly_sp_auth_counts.auth_count
        , monthly_sp_auth_counts.ial
        , %{iaa} AS iaa
        FROM
          monthly_sp_auth_counts
        WHERE
              monthly_sp_auth_counts.issuer IN %{issuers}
          AND monthly_sp_auth_counts.year_month IN %{year_months}
      SQL
    end

    def partial_month_subqueries(iaa_parts, partial_months)
      partial_months.map do |month_range|
        params = {
          range_start: month_range.begin,
          range_end: month_range.end,
          issuers: iaa_parts.issuers,
          year_month: month_range.begin.strftime('%Y%m'),
          iaa: iaa_parts.iaa,
        }.transform_values { |value| quote(value) }


        format(<<-SQL, params)
          SELECT
            sp_return_logs.user_id
          , %{year_month} AS year_month
          , COUNT(sp_return_logs.id) AS auth_count
          , sp_return_logs.ial
          , %{iaa} AS iaa
          FROM sp_return_logs
          INNER JOIN service_providers
            ON sp_return_logs.issuer = service_providers.issuer
          WHERE
                sp_return_logs.requested_at BETWEEN %{range_start} AND %{range_end}
            AND sp_return_logs.returned_at IS NOT NULL
            AND sp_return_logs.requested_at BETWEEN
                  service_providers.iaa_start_date AND service_providers.iaa_end_date
          GROUP BY
            sp_return_logs.user_id
          , sp_return_logs.ial
        SQL
      end
    end

    def iaa_query(iaa_parts)
      full_months, partial_months = months(iaa_parts.date_range).partition { |m| full_month?(m) }

      subquery = [
        full_month_subquery(iaa_parts, full_months),
        *partial_month_subqueries(iaa_parts, partial_months)
      ].join('UNION ALL')

      sql = format(<<-SQL, subquery: subquery)
        WITH subquery AS (%{subquery})
        SELECT
          billing_month_logs.year_month
        , billing_month_logs.ial
        , billing_month_logs.iaa
        , COUNT(DISTINCT billing_month_logs.user_id)
        FROM
          subquery billing_month_logs
        WHERE
          NOT EXISTS (
            SELECT 1
            FROM subquery lookback_logs
            WHERE
                lookback_logs.user_id = billing_month_logs.user_id
            AND lookback_logs.ial = billing_month_logs.ial
            AND lookback_logs.iaa = billing_month_logs.iaa
            AND lookback_logs.year_month < billing_month_logs.year_month
          )
        GROUP BY
          billing_month_logs.year_month
        , billing_month_logs.ial
        , billing_month_logs.iaa
      SQL

      ActiveRecord::Base.connection.execute(sql)
    end

    def quote(value)
      if value.is_a?(Array)
        "(#{value.map { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')})"
      else
        ActiveRecord::Base.connection.quote(value)
      end
    end

    IaaParts = Struct.new(:iaa, :date_range, :issuers, keyword_init: true)

    # @return [Array<IaaParts>]
    def iaa_range_issuers
      ServiceProvider.
        where.not(iaa: nil).
        pluck(:iaa, :issuer, :iaa_start_date, :iaa_end_date).
        to_a.
        group_by { |iaa, *rest| iaa }.
        map do |iaa, arr|
          _, _, iaa_start_date, iaa_end_date = arr.first
          issuers = arr.map { |_, issuer, *rest| issuer }
          IaaParts.new(
            iaa: iaa,
            date_range: iaa_start_date..iaa_end_date,
            issuers: issuers,
          )
        end
    end

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

    # @return [Array<Range<Date>>]
    def each_month_range
      min_iaa_start, max_iaa_end = ServiceProvider.
        where.not(iaa: nil).
        pluck(:iaa_start_date, :iaa_end_date).
        flatten.
        compact.
        minmax

      start = min_iaa_start.beginning_of_month
      finish = max_iaa_end.end_of_month
      results = []
      current = start

      while current < finish
        month_start = current.beginning_of_month
        month_end = current.end_of_month

        results << (month_start..month_end)

        current = month_end + 1.day
      end

      results
    end
  end
end
