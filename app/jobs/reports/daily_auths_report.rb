module Reports
  class DailyAuthsReport < BaseReport
    REPORT_NAME = 'daily-auths-report'

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      enqueue_limit: 1,
      perform_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    attr_reader :report_date

    def perform(report_date)
      @report_date = report_date

      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: report_date)

      [
        bucket_name, # default reporting bucket
        IdentityConfig.store.s3_public_reports_enabled && public_bucket_name,
      ].select(&:present?).
        each do |bucket_name|
        upload_file_to_s3_bucket(
          path: path,
          body: report_body.to_json,
          content_type: 'application/json',
          bucket_name: bucket_name,
        )
      end
    end

    def public_bucket_name
      if (prefix = IdentityConfig.store.s3_report_public_bucket_prefix)
        Identity::Hostdata.bucket_name("#{prefix}-#{Identity::Hostdata.env}")
      end
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
        , MAX(service_providers.friendly_name) AS friendly_name
        , MAX(agencies.name) AS agency
        FROM
          sp_return_logs
        LEFT JOIN
          service_providers ON service_providers.issuer = sp_return_logs.issuer
        LEFT JOIN
          agencies ON service_providers.agency_id = agencies.id
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
