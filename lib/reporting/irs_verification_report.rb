# frozen_string_literal: true

require 'csv'
begin
  require 'reporting/cloudwatch_client'
  require 'reporting/cloudwatch_query_quoting'
  require 'reporting/command_line_options'
rescue LoadError => e
  warn 'could not load paths, try running with "bundle exec rails runner"'
  raise e
end

module Reporting
  class IrsVerificationReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

    module Events
      VERIFICATION_DEMAND = 'IdV: doc auth welcome submitted'
      DOCUMENT_AUTHENTICATION_SUCCESS = 'IdV: doc auth ssn visited'
      INFORMATION_VALIDATION_SUCCESS = 'IdV: phone of record visited'
      PHONE_VERIFICATION_SUCCESS = 'idv_enter_password_visited'
      TOTAL_VERIFIED = 'User registration: agency handoff visited'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    def initialize(time_range:, issuers:, verbose: false, progress: false, slice: 1.day, threads: 5)
      @issuers = issuers
      @time_range = time_range || previous_week_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    def as_tables
      [overview_table,
       funnel_table
      ]
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          subtitle: '',
          float_as_percent: true,
          precision: 2,
          table: data_definition_table,
          filename: 'Definitions'
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          subtitle: '',
          float_as_percent: true,
          precision: 2,
          table: overview_table,
          filename: 'Overview Report'
        ),
        Reporting::EmailableReport.new(
          title: 'Funnel Metrics',
          subtitle: '',
          float_as_percent: true,
          precision: 2,
          table: funnel_table,
          filename: 'Funnel Metrics'
        )
      ]
    end

    def to_csvs
      as_emailable_reports.map do |report|
        CSV.generate do |csv|
          report.table.each { |row| csv << row }
        end
      end
    end

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin.to_date} to #{time_range.end.to_date}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuers.join(', ')]
      ]
    end

    def funnel_table
      verification_demand = verification_demand_results
      document_auth_success = document_authentication_success_results
      info_validation_success = information_validation_success_results
      phone_verification_success = phone_verification_success_results
      total_verified = total_verified_results

      [
        ['Metric', 'Count', 'Rate'],
        ['Verification Demand', verification_demand,
         to_percent(verification_demand, verification_demand)],
        ['Document Authentication Success', document_auth_success,
         to_percent(document_auth_success, verification_demand)],
        ['Information Verification Success', info_validation_success,
         to_percent(info_validation_success, verification_demand)],
        ['Phone Verification Success', phone_verification_success,
         to_percent(phone_verification_success, verification_demand)],
        ['Verification Successes', total_verified,
         to_percent(total_verified, verification_demand)],
        ['Verification Failures', verification_demand - total_verified,
         to_percent(verification_demand - total_verified, verification_demand)]
      ]
    end

    def data_definition_table
      [
        ['Metric', 'Definition'],
        ['Verification Demand', 'The count of users who started the identity verification process'],
        ['Document Authentication Success', 'Users who successfully completed document authentication'],
        ['Information Validation Success', 'Users who successfully validated their information'],
        ['Phone Verification Success', 'Users who successfully verified using their phone'],
        ['Verification Successes', 'Users who completed the entire process'],
        ['Verification Failures', 'The percentage of users that did not complete the identity verification process']
      ]
    end

    private

    def previous_week_range
      today = Time.zone.today
      last_sunday = today.beginning_of_week(:sunday) - 7.days
      last_saturday = last_sunday + 6.days
      last_sunday.to_date..last_saturday.to_date
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil
      )
    end

    # def quote(array)
    #   '[' + array.map { |e| %("#{e}") }.join(', ') + ']'
    # end

    def query
      params = {
        issuers: quote(issuers),
        event_names: quote(Events.all_events),
      }

      format(<<~QUERY, params)
        filter properties.sp_request.facial_match
          and name in %{event_names}
        | fields
            (name = '#{Events::VERIFICATION_DEMAND}') as @IdV_IAL2_start,
            (name = '#{Events::DOCUMENT_AUTHENTICATION_SUCCESS}') as @Doc_auth_success,
            (name = '#{Events::INFORMATION_VALIDATION_SUCCESS}') as @Verify_info_success,
            (name = '#{Events::PHONE_VERIFICATION_SUCCESS}') as @Verify_phone_success,
            (name = '#{Events::TOTAL_VERIFIED}' and properties.event_properties.ial2) as @Verified_1,
            coalesce(@Verified_1, 0) as @Verified,
            properties.user_id
        | stats
            max(@IdV_IAL2_start) as max_idv_ial2_start,
            max(@Doc_auth_success) as max_doc_auth_success,
            max(@Verify_info_success) as max_verify_info_success,
            max(@Verify_phone_success) as max_verify_phone_success,
            max(@Verified) as max_verified
            by properties.user_id, bin(1y)
        | stats
            sum(max_idv_ial2_start) as IdV_IAL2_Start_User_count,
            sum(max_doc_auth_success) as Doc_auth_success_User_count,
            sum(max_verify_info_success) as Verify_info_success_User_count,
            sum(max_verify_phone_success) as Verify_phone_success_User_count,
            sum(max_verified) as Verified_User_count
          | limit 10000
      QUERY
    end

    def fetch_results
      Rails.logger.info("Executing unified query")
      results = cloudwatch_client.fetch(
        query: query,
        from: time_range.begin.beginning_of_day,
        to: time_range.end.end_of_day
      )
      Rails.logger.info("Results: #{results.inspect}")
      results
    rescue StandardError => e
      Rails.logger.error("Failed to fetch results for unified query: #{e.message}")
      []
    end

    def data
      @data ||= fetch_results.first || {}
    end

    def verification_demand_results
      data['IdV_IAL2_Start_User_count'].to_i || 0
    end

    def document_authentication_success_results
      data['Doc_auth_success_User_count'].to_i || 0
    end

    def information_validation_success_results
      data['Verify_info_success_User_count'].to_i || 0
    end

    def phone_verification_success_results
      data['Verify_phone_success_User_count'].to_i || 0
    end

    def total_verified_results
      data['Verified_User_count'].to_i || 0
    end

    def to_percent(numerator, denominator)
      return 0.0 if denominator.nil? || denominator.zero?
      ((numerator.to_f / denominator) ).round(2)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV)
  Reporting::IrsVerificationReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end