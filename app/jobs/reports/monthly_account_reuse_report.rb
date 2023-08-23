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
        report_date.strftime("%Y-%m-01")
      end

      def stats_month
        report_date.prev_month(1).strftime("%b-%Y")
      end
  
      def report_body
        params = {
          query_date: first_day_of_report_month,
          report_month: stats_month
        }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }
  
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
  
        agency_results = transaction_with_timeout do
          ActiveRecord::Base.connection.execute(agency_sql)
        end

        proofed_results = transaction_with_timeout do
          ActiveRecord::Base.connection.execute(proofed_sql)
        end
        
        reuse_report = agency_results.as_json

        total_proofed = proofed_results[0]['num_proofed']

        total_reuse_stats = {
          label: "Total (all >1)",
          num_users: 0,
          percentage: 0
        }

        reuse_report.each do |result_entry|
          total_reuse_stats.num_users += result_entry.num_users
        end

        reuse_report.each_with_index do |result_entry, index|
          reuse_report[index].percentage = result_entry.num_users/total_proofed*100
          total_reuse_stats.percentage += reuse_report[index].percentage
        end

        report_csv = CSV.generate do |csv|
            csv << [
            "#{stats_month} Num. SPs",
            "#{stats_month} Num. users",
            "#{stats_month} Reuse Rate Percentage",
            ] 
    
            reuse_report.each do |result_entry|
            csv << [
              result_entry.num_agencies,
              result_entry.num_users,
              result_entry.percentage,
            ]
            end
        end
  
        {
          report_date: first_day_of_report_month,
          month: stats_month,
          results: report_csv,
        }
      end
    end
  end
  