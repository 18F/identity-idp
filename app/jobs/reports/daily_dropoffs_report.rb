require 'csv'

module Reports
  class DailyDropoffsReport < BaseReport
    REPORT_NAME = 'daily-dropoffs-report'

    STEPS = %w[
      welcome
      agreement
      capture_document
      cap_doc_submit
      ssn
      verify_info
      verify_submit
      phone
      encrypt
      personal_key
      verified
    ].freeze

    attr_reader :report_date

    def perform(report_date)
      @report_date = report_date

      _latest, path = generate_s3_paths(REPORT_NAME, 'csv', now: report_date)
      body = report_body

      [
        bucket_name, # default reporting bucket
        IdentityConfig.store.s3_public_reports_enabled && public_bucket_name,
      ].select(&:present?).
        each do |bucket_name|
        upload_file_to_s3_bucket(
          path: path,
          body: body,
          content_type: 'text/csv',
          bucket: bucket_name,
        )
      end
    end

    def start
      report_date.beginning_of_day
    end

    def finish
      report_date.end_of_day
    end

    def report_body
      CSV.generate do |csv|
        csv << %w[
          issuer
          friendly_name
          iaa
          agency
          start
          finish
        ] + STEPS

        query_results.each do |sp_result|
          csv << [
            sp_result['issuer'],
            sp_result['friendly_name'],
            sp_result['iaa'],
            sp_result['agency'],
            start.iso8601,
            finish.iso8601,
            *STEPS.map { |step| sp_result[step].to_i },
          ]
        end
      end
    end

    def query_results
      params = {
        start: start,
        finish: finish,
      }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }

      sql = format(<<-SQL, params)
        SELECT
          NULLIF(doc_auth_logs.issuer, '') AS issuer
        , MAX(service_providers.iaa) AS iaa
        , MAX(service_providers.friendly_name) AS friendly_name
        , MAX(agencies.name) AS agency
        , COUNT(doc_auth_logs.welcome_view_at) AS welcome
        , COUNT(doc_auth_logs.agreement_view_at) AS agreement
        , COUNT(doc_auth_logs.upload_view_at) AS upload_option
        , COUNT(
            COALESCE(
              doc_auth_logs.back_image_view_at
            , doc_auth_logs.mobile_back_image_view_at
            , doc_auth_logs.capture_mobile_back_image_view_at
            , doc_auth_logs.present_cac_view_at
            , doc_auth_logs.document_capture_view_at
            )
          ) AS capture_document
        , COUNT(
            COALESCE(
              CASE WHEN doc_auth_logs.document_capture_submit_count > 0 THEN 1 else null END
            , CASE WHEN doc_auth_logs.back_image_submit_count > 0 THEN 1 else null END
            , CASE WHEN doc_auth_logs.capture_mobile_back_image_submit_count > 0 THEN 1 else null END
            , CASE WHEN doc_auth_logs.mobile_back_image_submit_count > 0 THEN 1 else null END
            )
          ) AS cap_doc_submit
        , COUNT(
            COALESCE(
              doc_auth_logs.ssn_view_at
            , doc_auth_logs.enter_info_view_at
            )
          ) AS ssn
        , COUNT(doc_auth_logs.verify_view_at) AS verify_info
        , COUNT(
            COALESCE(CASE WHEN doc_auth_logs.verify_submit_count > 0 THEN 1 else null END)
          ) AS verify_submit
        , COUNT(doc_auth_logs.verify_phone_view_at) AS phone
        , COUNT(doc_auth_logs.encrypt_view_at) AS encrypt
        , COUNT(doc_auth_logs.verified_view_at) AS personal_key
        , COUNT(profiles.id) AS verified
        FROM doc_auth_logs
        LEFT JOIN
          service_providers ON service_providers.issuer = doc_auth_logs.issuer
        LEFT JOIN
          agencies ON service_providers.agency_id = agencies.id
        LEFT JOIN
          profiles ON profiles.user_id = doc_auth_logs.user_id
            AND profiles.verified_at IS NOT NULL
            AND %{start} <= profiles.verified_at
            AND profiles.verified_at <= %{finish}
            AND profiles.active = TRUE

        WHERE
          %{start} <= doc_auth_logs.welcome_view_at
        AND doc_auth_logs.welcome_view_at <= %{finish}

        GROUP BY
          doc_auth_logs.issuer
      SQL

      transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
