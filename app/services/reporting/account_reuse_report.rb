module Reporting
  class AccountReuseReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    RSpec.configure do |rspec|
      rspec.expect_with :rspec do |c|
        # Or a very large value, if you do want to truncate at some point
        c.max_formatted_output_length = nil
      end
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

      total_metric = ''
      total_reuse_report.each do |report_key, report_value|
        report_results = report_value[:results]

        individual_metric = ''
        report_results.each do |result|
          if report_key == :sp_reuse_stats
            individual_metric = "#{result[:num_sps]} apps"
            total_metric = '2+ apps'
          elsif report_key == :agency_reuse_stats
            individual_metric = "#{result[:num_agencies]} agencies"
            total_metric = '2+ agencies'
          end

          account_reuse_table << [
            individual_metric,
            result[:num_all_users],
            result[:all_percent],
            result[:num_idv_users],
            result[:idv_percent],
          ]
        end

        account_reuse_table << [
          total_metric,
          report_value[:total_all_users],
          report_value[:total_all_percent],
          report_value[:total_idv_users],
          report_value[:total_idv_percent],
        ]
      end

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
      report_date.prev_month(1).strftime('%b-%Y')
    end

    private

    def total_reuse_report
      return @total_reuse_report if defined?(@total_reuse_report)

      reuse_results = {
        sp: [{
          num_sps: 0,
          num_idv_users: 0,
          num_all_users: 0,
        }],
        agency: [{
          num_agencies: 0,
          num_idv_users: 0,
          num_all_users: 0,
        }],
      }

      sp_reuse_results_idv.each do |result|
        reuse_results[:sp][result['num_sps']] = {
          num_sps: result['num_sps'],
          num_idv_users: result['num_idv_users'],
          num_all_users: 0, # Fill it in with 'all' results later
        }
      end
      sp_reuse_results_all.each do |result|
        if reuse_results[:sp][result['num_sps']].is_a?(Hash)
          # Hash exists, so replace the zero placeholder value
          reuse_results[:sp][result['num_sps']][:num_all_users] = result['num_all_users']
        else
          reuse_results[:sp][result['num_sps']] = {
            num_sps: result['num_sps'],
            num_idv_users: 0, # Since it didn't exist, fill with zero 'idv' results
            num_all_users: result['num_all_users'],
          }
        end
      end
      agency_reuse_results_idv.each do |result|
        reuse_results[:agency][result['num_agencies']] = {
          num_agencies: result['num_agencies'],
          num_idv_users: result['num_idv_users'],
          num_all_users: 0, # Fill it in with 'all' results later
        }
      end
      agency_reuse_results_all.each do |result|
        if reuse_results[:agency][result['num_agencies']].is_a?(Hash)
          # Hash exists, so replace the zero placeholder value
          reuse_results[:agency][result['num_agencies']][:num_all_users] = result['num_all_users']
        else
          reuse_results[:agency][result['num_agencies']] = {
            num_agencies: result['num_agencies'],
            num_idv_users: 0, # Since it didn't exist, fill with zero 'idv' results
            num_all_users: result['num_all_users'],
          }
        end
      end

      reuse_results.each do |results_key, results_value|
        if results_value.length > 1
          # If there are results, then remove the zero placeholder
          results_value[0] = nil
          reuse_results[results_key] = results_value.compact
        end
      end

      sp_reuse_stats = {
        results: reuse_results[:sp].compact,
        total_all_users: 0,
        total_all_percent: 0,
        total_idv_users: 0,
        total_idv_percent: 0,
      }
      agency_reuse_stats = {
        results: reuse_results[:agency].compact,
        total_all_users: 0,
        total_all_percent: 0,
        total_idv_users: 0,
        total_idv_percent: 0,
      }

      total_proofed = num_active_profiles

      [sp_reuse_stats, agency_reuse_stats].each do |stats|
        if !stats[:results].nil? && !stats[:results].empty?
          # Count how many total users have multiples for both sps and agencies
          stats[:results].each do |result_entry|
            stats[:total_all_users] += result_entry[:num_all_users]
            stats[:total_idv_users] += result_entry[:num_idv_users]
          end

          if total_proofed > 0
            # Calculate percentages for breakdowns with both sps and angencies
            stats[:results].each_with_index do |result_entry, index|
              stats[:results][index][:all_percent] =
                result_entry[:num_all_users] / total_proofed.to_f
              stats[:results][index][:idv_percent] =
                result_entry[:num_idv_users] / total_proofed.to_f

              stats[:total_all_percent] += stats[:results][index][:all_percent]
              stats[:total_idv_percent] += stats[:results][index][:idv_percent]
            end
          end
        end
      end

      # reuse_stats and total_stats
      @total_reuse_report = {
        sp_reuse_stats: sp_reuse_stats,
        agency_reuse_stats: agency_reuse_stats,
      }
    end

    def sp_reuse_results_all
      sp_all_sql = format(<<-SQL, params)
        SELECT
            COUNT(*) AS num_all_users
            , sps_per_all_users.num_sps
        FROM (
            SELECT
                COUNT(*) AS num_sps
                , identities.user_id
            FROM
                identities
            WHERE
                identities.verified_at < %{query_date}
            GROUP BY
                identities.user_id
        ) sps_per_all_users
        GROUP BY
            sps_per_all_users.num_sps
        HAVING 
            sps_per_all_users.num_sps > 1
        ORDER BY
            num_sps ASC
      SQL

      sp_all_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sp_all_sql)
      end

      sp_all_results.as_json
    end

    def sp_reuse_results_idv
      sp_idv_sql = format(<<-SQL, params)
        SELECT
            COUNT(*) AS num_idv_users
            , sps_per_idv_users.num_sps
        FROM (
            SELECT
                COUNT(*) AS num_sps
                , identities.user_id
            FROM
                identities
            WHERE
                identities.last_ial2_authenticated_at IS NOT NULL
            AND
                identities.verified_at < %{query_date}
            GROUP BY
                identities.user_id
        ) sps_per_idv_users
        GROUP BY
            sps_per_idv_users.num_sps
        HAVING 
            sps_per_idv_users.num_sps > 1
        ORDER BY
            num_sps ASC
      SQL

      sp_idv_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sp_idv_sql)
      end

      sp_idv_results.as_json
    end

    def agency_reuse_results_all
      agency_all_sql = format(<<-SQL, params)
      SELECT
          COUNT(*) AS num_all_users
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
              identities.verified_at < %{query_date}
          GROUP BY
              identities.user_id
      ) agencies_per_user
      GROUP BY
          agencies_per_user.num_agencies
      HAVING 
          agencies_per_user.num_agencies > 1
      ORDER BY
          num_agencies ASC
      SQL

      agency_all_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(agency_all_sql)
      end

      agency_all_results.as_json
    end

    def agency_reuse_results_idv
      agency_idv_sql = format(<<-SQL, params)
        SELECT
            COUNT(*) AS num_idv_users
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
        HAVING 
            agencies_per_user.num_agencies > 1
        ORDER BY
            num_agencies ASC
      SQL

      agency_idv_results = Reports::BaseReport.transaction_with_timeout do
        ActiveRecord::Base.connection.execute(agency_idv_sql)
      end

      agency_idv_results.as_json
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
