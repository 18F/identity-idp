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
  class IrsVerificationDemographicsReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

    module Events
      IDV_DOC_AUTH_PROOFING_RESULTS = 'IdV: doc auth verify proofing results'
      SP_REDIRECT_INITIATED = 'SP redirect initiated'

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
          title: 'IRS Age Metrics',
          table: age_metrics_table,
          filename: 'age_metrics',
        ),
        Reporting::EmailableReport.new(
          title: 'IRS State Metrics',
          table: state_metrics_table,
          filename: 'state_metrics',
        ),
      ]
    end

    def definitions_table
      [
        ['Metric', 'Unit', 'Definition'],
        ['Verified users by age', 'Count',
         'The number of users grouped by age in 10 year range.'],
        ['Verified users by state', 'Count',
         'The number of users grouped by state.'],
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

    def age_metrics_table
      rows = [['Age Range', 'User Count']]
      bins = age_bins_for_event(Events::SP_REDIRECT_INITIATED)

      bins.each do |range, count|
        rows << [range, count.to_s]
      end

      rows
    end

    def state_metrics_table
      rows = [['State', 'User Count']]
      counts = state_counts_for_event(Events::SP_REDIRECT_INITIATED)

      counts.each do |state, count|
        rows << [state, count.to_s]
      end

      rows
    end

    # event name => set(user ids)
    # @return Hash<String,Set<String>>
    def data
      @data ||= begin
        event_users = Hash.new { |h, k| h[k] = [] }

        fetch_results.each do |row|
          event_users[row['name']] << {
            user_id: row['user_id'],
            birth_year: row['birth_year']&.to_i,
            state: row['state']&.upcase,
          }
        end

        event_users
      end
    end

    def user_metadata
      @user_metadata ||= begin
        metadata = {}

        data[Events::IDV_DOC_AUTH_PROOFING_RESULTS].each do |entry|
          user_id = entry[:user_id]
          next unless user_id.present?

          metadata[user_id] = {
            birth_year: entry[:birth_year]&.to_i,
            state: entry[:state]&.upcase,
          }
        end

        metadata
      end
    end

    
    def age_bins_for_event(event_name)
      current_year = Time.zone.today.year

      user_ids = data[event_name].map { |entry| entry[:user_id] }.uniq

      bins = Hash.new(0)

      user_ids.each do |user_id|
        metadata = user_metadata[user_id]
        next unless metadata


        birth_year = metadata[:birth_year]
        next unless birth_year

        age = current_year - birth_year
        next if age < 0

        bin_start = (age / 10) * 10
        bin_label = "#{bin_start}-#{bin_start + 9}"
        bins[bin_label] += 1
      end

      bins.sort_by { |range, _| range.split('-').first.to_i }.to_h
    end

    def state_counts_for_event(event_name)
      user_ids = data[event_name].map { |entry| entry[:user_id] }.uniq

      counts = Hash.new(0)

      user_ids.each do |user_id|
        state = user_metadata[user_id]&.dig(:state)
        next unless state.present?

        counts[state] += 1
      end

      counts.sort.to_h
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuers: quote(issuers),
        event_names: quote(Events.all_events),
        sp_redirect_initiated: quote(Events::SP_REDIRECT_INITIATED)
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id as user_id
          , properties.event_properties.proofing_results.biographical_info.birth_year as birth_year
          , properties.event_properties.proofing_results.biographical_info.state_id_jurisdiction as state
        | filter properties.service_provider IN %{issuers}
        | filter (name = %{sp_redirect_initiated} and properties.event_properties.ial = 2 and properties.sp_request.facial_match = 1)
                 or (name != %{sp_redirect_initiated})
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
  end
end
