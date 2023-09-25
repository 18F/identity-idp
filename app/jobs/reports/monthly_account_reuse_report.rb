require 'csv'

module Reports
  class MonthlyAccountReuseReport < BaseReport
    REPORT_NAME = 'monthly-account-reuse-report'

    attr_reader :report_date

    def initialize
      @report_date = Time.zone.today
    end

    def perform(date = report_date)
      _latest, path = generate_s3_paths(REPORT_NAME, 'json', now: date)

      if bucket_name.present?
        upload_file_to_s3_bucket(
          path: path,
          body: report_body,
          content_type: 'text/csv',
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

    def agency_reuse_results
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

    def num_active_profiles
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
      reuse_stats = agency_reuse_results

      reuse_total_users = 0
      reuse_total_percentage = 0

      total_proofed = num_active_profiles

      if !reuse_stats.empty?
        reuse_stats.each do |result_entry|
          reuse_total_users += result_entry['num_users']
        end

        if total_proofed > 0
          reuse_stats.each_with_index do |result_entry, index|
            reuse_stats[index]['percentage'] =
              result_entry['num_users'] / total_proofed.to_f * 100

            reuse_total_percentage += reuse_stats[index]['percentage']
          end
        end
      end

      # reuse_stats and total_stats
      { reuse_stats: reuse_stats,
        total_users: reuse_total_users,
        total_percentage: reuse_total_percentage,
        total_proofed: total_proofed }
    end

    def report_csv
      monthly_reuse_report = total_reuse_report

      tables_array = []
      csv_array_1 = []
      csv_array_1 << { title: "IDV app reuse rate #{stats_month}",
                       float_as_percent: true,
                       precision: 4 }
      csv_array_1 << ['Num. SPs', 'Num. users', 'Percentage']

      monthly_reuse_report[:reuse_stats].each do |result_entry|
        csv_array_1 << [
          result_entry['num_agencies'],
          result_entry['num_users'],
          result_entry['percentage'],
        ]
      end
      csv_array_1 << [
        'Total (all >1)',
        monthly_reuse_report[:total_users],
        monthly_reuse_report[:total_percentage],
      ]
      tables_array << csv_array_1

      csv_array_2 = []
      csv_array_2 << { title: 'Total proofed identities' }
      csv_array_2 << [
        ["Total proofed identities (#{stats_month})"],
        [monthly_reuse_report[:total_proofed]],
      ]
      tables_array << csv_array_2

      tables_array
    end

    def report_body
      CSV.generate do |csv|
        report_csv.each do |row|
          csv << row
        end
      end
    end
  end
end
