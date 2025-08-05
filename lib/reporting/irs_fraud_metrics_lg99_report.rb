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
  class IrsFraudMetricsLg99Report
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

    module Events
      IDV_FINAL_RESOLUTION = 'IdV: final resolution'
      SUSPENDED_USERS = 'User Suspension: Suspended'
      REINSTATED_USERS = 'User Suspension: Reinstated'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Array<String>] issuers
    # @param [Range<Time>] time_range
    def initialize(
      issuers:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 6.hours,
      threads: 1
    )
      @issuers = issuers
      @time_range = time_range
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

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          table: definitions_table,
          filename: 'definitions',
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
          filename: 'overview',
        ),
        Reporting::EmailableReport.new(
          title: "Monthly Fraud Metrics #{stats_month}",
          table: lg99_metrics_table,
          filename: 'lg99_metrics',
        ),
      ]
    end

    def definitions_table
      [
        ['Metric', 'Unit', 'Definition'],
        ['Fraud Rules Catch Count', 'Count',
         'The count of unique accounts flagged for fraud review.'],
        ['Credentials Disabled', 'Count',
         'The count of unique accounts suspended due to ' + '
         suspected fraudulent activity within the reporting month.'],
        ['Credentials Reinstated', 'Count',
         'The count of unique suspended accounts ' + '
         that are reinstated within the reporting month.'],
      ]
    end

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        # This needs to be Date.today so it works when run on the command line
        ['Report Generated', Time.zone.today.to_s],
        ['Issuer', issuers.present? ? issuers.join(', ') : 'All Issuers'],
      ]
    end

    def lg99_metrics_table
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Fraud Rules Catch Count', lg99_unique_users_count.to_s, time_range.begin.to_s,
         time_range.end.to_s],
        [
          'Credentials Disabled',
          unique_suspended_users_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Credentials Reinstated',
          unique_reinstated_users_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
      ]
    rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ]
    end

    def stats_month
      time_range.begin.strftime('%b-%Y')
    end

    # event name => set(user ids)
    # @return Hash<String,Set<String>>
    def data
      @data ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_results.each do |row|
          event_users[row['name']] << row['user_id']
        end

        event_users
      end
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuers: quote(issuers),
        event_names: quote(Events.all_events),
        idv_final_resolution: quote(Events::IDV_FINAL_RESOLUTION),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id as user_id
        | filter properties.service_provider IN %{issuers}
        | filter name in %{event_names}
        | filter (name = %{idv_final_resolution} and properties.event_properties.fraud_review_pending = 1)
                 or (name != %{idv_final_resolution})        
        | limit 10000
      QUERY
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end

    def lg99_unique_users_count
      @lg99_unique_users_count ||= data[Events::IDV_FINAL_RESOLUTION].count
    end

    def unique_suspended_users_count
      @unique_suspended_users_count ||= data[Events::SUSPENDED_USERS].count
    end

    def user_days_to_suspension_avg
      user_data = User.where(uuid: data[Events::SUSPENDED_USERS]).pluck(:created_at, :suspended_at)
      return 'n/a' if user_data.empty?

      difference = user_data.map { |created_at, suspended_at| suspended_at - created_at }
      (difference.sum / difference.size).seconds.in_days.round(1)
    end

    def user_days_proofed_to_suspension_avg
      user_data = User.where(uuid: data[Events::SUSPENDED_USERS]).includes(:profiles)
        .merge(Profile.active)
        .pluck(
          :activated_at,
          :suspended_at,
        )

      return 'n/a' if user_data.empty?

      difference = user_data.map { |activated_at, suspended_at| suspended_at - activated_at }
      (difference.sum / difference.size).seconds.in_days.round(1)
    end

    def unique_reinstated_users_count
      @unique_reinstated_users_count ||= data[Events::REINSTATED_USERS].count
    end

    def user_days_to_reinstatement_avg
      user_data = User.where(uuid: data[Events::REINSTATED_USERS]).pluck(
        :suspended_at,
        :reinstated_at,
      )
      return 'n/a' if user_data.empty?

      difference = user_data.map { |suspended_at, reinstated_at| reinstated_at - suspended_at }
      (difference.sum / difference.size).seconds.in_days.round(1)
    end
  end
end
