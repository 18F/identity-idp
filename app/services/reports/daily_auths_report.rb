module Reports
  class DailyAuthsReport < BaseReport
    REPORT_NAME = 'daily-auths-report'

    attr_reader :report_date

    # @param [Date] report_date
    def initialize(report_date)
      @report_date = report_date
    end

    def call
      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: report_date)

      upload_file_to_s3_bucket(
        path: path,
        body: report_body.to_json,
        content_type: 'application/json',
      )
    end

    def start
      report_date.beginning_of_day
    end

    def finish
      report_date.end_of_day
    end

    def report_body
      params = {
        start: start,
        finish: finish,
      }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }

      sql = format(<<-SQL, params)
        SELECT
          COUNT(*)
        , sp_return_logs.ial
        , sp_return_logs.issuer
        , service_providers.iaa
        FROM
          sp_return_logs
        LEFT JOIN
          service_providers ON service_providers.issuer = sp_return_logs.issuer
        WHERE
          %{start} <= sp_return_logs.requested_at
          AND sp_return_logs.requested_at <= %{finish}
          AND sp_return_logs.returned_at IS NOT NULL
        GROUP BY
          sp_return_logs.ial
        , sp_return_logs.issuer
        , service_providers.iaa
      SQL

      results = transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end

      {
        start: start,
        finish: finish,
        results: results.as_json,
      }
    end
  end
end
