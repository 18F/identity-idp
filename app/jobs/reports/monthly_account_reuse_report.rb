require 'csv'

module Reports
  class MonthlyAccountReuseReport < BaseReport
    REPORT_NAME = 'monthly-account-reuse-report'

    attr_reader :report_date

    def perform(report_date)
      @report_date = report_date

      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: report_date)
      body = report_body.to_json

      [
        bucket_name, # default reporting bucket
        IdentityConfig.store.s3_public_reports_enabled && public_bucket_name,
      ].select(&:present?).
        each do |bucket_name|
        upload_file_to_s3_bucket(
          path: path,
          body: body,
          content_type: 'application/json',
          bucket: bucket_name,
        )
      end
    end

    def first_day_of_report_month
      report_date.beginning_of_month.strftime('%Y-%m-%d')
    end

    def params
      {
        query_date: first_day_of_report_month,
      }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }
    end

    def agency_reuse_results_json
      agency_sql = format(<<-SQL, params)
          SELECT
              COUNT(*) AS num_users
          , agencies_per_user.num_agencies
          FROM (
              SELECT
                  COUNT(DISTINCT agencies.id) AS num_agencies
              , identities.user_id
              FROM 
                  identities
              JOIN 
                  service_providers sp ON identities.service_provider = sp.issuer
              JOIN 
                  agencies ON sp.agency_id = agencies.id
              WHERE
                  identities.last_ial2_authenticated_at IS NOT NULL
              AND
                  identities.verified_at < %{query_date}
              GROUP BY 
                  identities.user_id
          ) agencies_per_user
          GROUP BY 
              agencies_per_user.num_agencies
          HAVING agencies_per_user.num_agencies > 1
          ORDER BY 
              num_agencies ASC
      SQL

      agency_results = transaction_with_timeout do
        ActiveRecord::Base.connection.execute(agency_sql)
      end

      agency_results.as_json
    end

    def total_proofed_results
      proofed_sql = format(<<-SQL, params)
          SELECT
            COUNT(*) AS num_proofed
          FROM
            profiles
          WHERE
            profiles.active = TRUE
          AND
            profiles.activated_at < %{query_date}
      SQL

      proofed_results = transaction_with_timeout do
        ActiveRecord::Base.connection.execute(proofed_sql)
      end

      proofed_results.first['num_proofed']
    end

    def stats_month
      report_date.prev_month(1).strftime('%b-%Y')
    end

    def total_reuse_report
      reuse_report = agency_reuse_results_json

      reuse_total_users = 0
      reuse_total_percentage = 0

      total_proofed = total_proofed_results

      if !reuse_report.empty?
        reuse_report.each do |result_entry|
          reuse_total_users += result_entry['num_users']
        end

        if total_proofed > 0
          reuse_report.each_with_index do |result_entry, index|
            reuse_report[index]['percentage'] =
              result_entry['num_users'] / total_proofed.to_f * 100

            reuse_total_percentage += reuse_report[index]['percentage']
          end
        end
      end

      # reuse_stats and total_stats
      [reuse_report, reuse_total_users, reuse_total_percentage, total_proofed]
    end

    def report_csv
      reuse_stats, total_users, total_percentage, total_proofed = total_reuse_report

      csv_array = []
      csv_array << ["IDV app reuse rate #{stats_month}"]
      csv_array << ['Num. SPs', 'Num. users', 'Percentage']

      reuse_stats.each do |result_entry|
        csv_array << [
          result_entry['num_agencies'],
          result_entry['num_users'],
          result_entry['percentage'],
        ]
      end
      csv_array << ['Total (all >1)', total_users, total_percentage]

      csv_array << []
      csv_array << ['Total proofed identities']
      csv_array << ["Total proofed identities (#{stats_month})", total_proofed]
      return csv_array
    end

    def report_body
      {
        report_date: first_day_of_report_month,
        month: stats_month,
        results: [report_csv],
      }
    end
  end
end
