module Reporting
  class AccountReuseReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    # Return array of arrays
    def account_reuse_report
      account_reuse_table = []
      account_reuse_table << [
        'Metric',
        'Num. all users',
        '% of accounts',
        'Num. IDV users',
        '% of accounts',
      ]

      total_reuse_report[:sp_reuse_stats].each do |result_entry|
        account_reuse_table << [
          "#{result_entry['num_sps']} apps",
          result_entry['num_all_users'],
          result_entry['all_percent'],
          result_entry['num_idv_users'],
          result_entry['idv_percent'],
        ]
      end

      account_reuse_table << [
        '2+ apps',
        total_reuse_report[:sp_reuse_stats][:total_all_users],
        total_reuse_report[:sp_reuse_stats][:total_all_percent],
        total_reuse_report[:sp_reuse_stats][:total_idv_users],
        total_reuse_report[:sp_reuse_stats][:total_idv_percent],
      ]

      # Blank line to separate multiple app use from multiple agency use
      account_reuse_table << ['', '', '', '', '']

      total_reuse_report[:agency_reuse_stats].each do |result_entry|
        account_reuse_table << [
          "#{result_entry['num_agencies']} agencies",
          result_entry['num_all_users'],
          result_entry['all_percent'],
          result_entry['num_idv_users'],
          result_entry['idv_percent'],
        ]
      end

      account_reuse_table << [
        '2+ agencies',
        total_reuse_report[:agency_reuse_stats][:total_all_users],
        total_reuse_report[:agency_reuse_stats][:total_all_percent],
        total_reuse_report[:agency_reuse_stats][:total_idv_users],
        total_reuse_report[:agency_reuse_stats][:total_idv_percent],
      ]

      account_reuse_table
    end

    def account_reuse_emailable_report
      EmailableReport.new(
        title: "IDV app reuse rate #{stats_month}",
        float_as_percent: true,
        precision: 4,
        filename: 'account_reuse',
        table: account_reuse_report,
      )
    end

    def stats_month
      report_date.strftime('%b-%Y')
    end

    private

    def total_reuse_report
      return @total_reuse_report if defined?(@total_reuse_report)
      sp_reuse_stats = {
        results: sp_reuse_results,
        total_all_users: 0,
        total_all_percent: 0,
        total_idv_users: 0,
        total_idv_percent: 0,
      }
      agency_reuse_stats = {
        results: agency_reuse_results,
        total_all_users: 0,
        total_all_percent: 0,
        total_idv_users: 0,
        total_idv_percent: 0,
      }

      total_proofed = num_active_profiles

      [sp_reuse_stats, agency_reuse_stats].each do |stats|
        if !stats['results'].empty?
          # Count how many total users have multiples for both sps and agencies
          stats['results'].each do |result_entry|
            stats['total_all_users'] += result_entry['num_all_users']
            stats['total_idv_users'] += result_entry['num_idv_users']
          end

          if total_proofed > 0
            # Calculate percentages for breakdowns with both sps and angencies
            stats['results'].each_with_index do |result_entry, index|
              stats['results'][index]['all_percent'] =
                result_entry['num_all_users'] / total_proofed.to_f
              stats['results'][index]['idv_percent'] =
                result_entry['num_idv_users'] / total_proofed.to_f

              stats['total_all_percent'] += agency_reuse_stats[index]['all_percent']
              stats['total_idv_percent'] += agency_reuse_stats[index]['idv_percent']
            end
          end
        end
      end

      # reuse_stats and total_stats
      @total_reuse_report = {
        sp_reuse_stats: sp_reuse_stats,
        agency_reuse_stats: agency_reuse_stats,
        total_proofed: total_proofed,
      }
    end

    def sp_reuse_results
      # TODO: Test this query so that it returns correct data
      sp_sql = format(<<-SQL, params)
          SELECT
              num_all_users
              , all_query.sps_per_all_users.num_sps
              , COUNT(*) AS num_idv_users
          FROM (
            SELECT
                COUNT(*) AS num_all_users
                , sps_per_all_users.num_sps
                , identities
            FROM (
                SELECT
                    COUNT(*) AS num_sps
                    , identities.user_id
                FROM
                    identities
                AND
                    identities.verified_at < %{query_date}
                GROUP BY
                    identities.user_id
              ) sps_per_all_users
            GROUP BY
              sps_per_all_users.num_sps
            HAVING sps_per_all_users.num_sps > 1
            ) all_query
          WHERE
            identities.last_ial2_authenticated_at IS NOT NULL
          ORDER BY
              num_sps ASC
      SQL

      sp_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sp_sql)
      end

      sp_results.as_json
    end

    def agency_reuse_results
      agency_sql = format(<<-SQL, params)
        SELECT
          num_all_users
          , all_query.agencies_per_all_users.num_agencies
          , COUNT(*) AS num_idv_users
        FROM (
            SELECT
                COUNT(*) AS num_all_users
                , agencies_per_all_users.num_agencies
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
                AND
                    identities.verified_at < %{query_date}
                GROUP BY
                    identities.user_id
            ) agencies_per_all_users
            GROUP BY
                agencies_per_all_users.num_agencies
            HAVING agencies_per_all_users.num_agencies > 1
            ) all_query
            WHERE
              identities.last_ial2_authenticated_at IS NOT NULL
          ORDER BY
            num_agencies ASC
      SQL

      agency_results = Reports::BaseReport.transaction_with_timeout do
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

      proofed_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(proofed_sql)
      end

      proofed_results.first['num_proofed']
    end

    def params
      {
        query_date: report_date.end_of_day,
      }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }
    end
  end
end
