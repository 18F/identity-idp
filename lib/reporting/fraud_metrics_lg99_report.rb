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
  class FraudMetricsLg99Report
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    module Events
      IDV_PLEASE_CALL_VISITED = 'IdV: Verify please call visited'
      IDV_SETUP_ERROR_VISITED = 'IdV: Verify setup errors visited'
      SUSPENDED_USERS = 'User Suspension: Suspended'
      REINSTATED_USERS = 'User Suspension: Reinstated'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Range<Time>] time_range
    def initialize(
      time_range:,
      verbose: false,
      progress: false,
      slice: 6.hours,
      threads: 1
    )
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
          title: "Monthly LG-99 Metrics #{stats_month}",
          table: lg99_metrics_table,
          filename: 'lg99_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "Monthly Suspended User Metrics #{stats_month}",
          table: suspended_metrics_table,
          filename: 'suspended_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "Monthly Reinstated User Metrics #{stats_month}",
          table: reinstated_metrics_table,
          filename: 'reinstated_metrics',
        ),
      ]
    end

    def lg99_metrics_table
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        ['Unique users seeing LG-99', lg99_unique_users_count.to_s, time_range.begin.to_s,
         time_range.end.to_s],
      ]
    rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ]
    end

    def suspended_metrics_table
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        [
          'Unique users suspended',
          unique_suspended_users_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Average Days Creation to Suspension',
          user_days_to_suspension_avg.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Average Days Proofed to Suspension',
          user_days_proofed_to_suspension_avg.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
      ]
    end

    def reinstated_metrics_table
      [
        ['Metric', 'Total', 'Range Start', 'Range End'],
        [
          'Unique users reinstated',
          unique_reinstated_users_count.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
        [
          'Average Days to Reinstatement',
          user_days_to_reinstatement_avg.to_s,
          time_range.begin.to_s,
          time_range.end.to_s,
        ],
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
        event_names: quote(Events.all_events),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id as user_id
        | filter name in %{event_names}
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
      @lg99_unique_users_count ||= (data[Events::IDV_PLEASE_CALL_VISITED] +
        data[Events::IDV_SETUP_ERROR_VISITED]).count
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
