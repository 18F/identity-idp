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
        ['Age range/Verification Demographics', 'Count',
         'The number of IRS users who verified within the reporting period, grouped by age in ' + '
         10 year range.'],
        ['Geographic area/Verification Demographics', 'Count',
         'The number of IRS users who verified within the reporting period, grouped by state.'],
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
      bins = age_bins

      bins.each do |range, count|
        rows << [range, count.to_s]
      end

      rows
    end

    def state_metrics_table
      rows = [['State', 'User Count']]
      counts = state_counts

      counts.each do |state, count|
        rows << [state, count.to_s]
      end

      rows
    end

    # TODO:-----------------------------------------------------------------------
    # modify the data function and split into two related to the two new queries
    def data_sp_redirect
      @data_sp_redirect ||= begin
        event_users = Hash.new { |h, k| h[k] = [] }

        fetch_sp_redirect_results.each do |row|
          event_users[row['user_id']] << { # HELP HERE
            user_id: row['user_id'],
          }
        end

        event_users
      end
    end

    def data_doc_auth_success_bio_info
      @data_doc_auth_success_bio_info ||= begin
        event_users = Hash.new { |h, k| h[k] = [] }

        fetch_doc_auth_success_bio_info_results.each do |row|
          event_users[row['user_id']] << {
            user_id: row['user_id'],
            birth_year: row['birth_year']&.to_i,
            state: row['state']&.upcase,
          }
        end

        event_users
      end
    end
    # TODO: END -----------------------------------------------------------------------

    # TODO:-----------------------------------------------------------------------
    # FIGURE OUT HOW TO DO THE JOIN ON MULTIPLE QUERIES
    # JOIN: Only user_ids present in data_sp_redirect
    def data
      sp_redirects = data_sp_redirect
      bio_infos = data_doc_auth_success_bio_info

      result = {}
      sp_redirects.keys.each do |user_id|
        if bio_infos.key?(user_id)
          result[user_id] = bio_infos[user_id]
        end
      end
      result
    end
    # TODO: END -----------------------------------------------------------------------

    # TODO need to update the metadata or do I even need it anymore??------------
    def user_metadata
      @user_metadata ||= begin
        metadata = {}
        data.each do |user_id, bio_info|
          next unless user_id.present?

          # If bio_info is an array, get the first element
          info = bio_info.is_a?(Array) ? bio_info.first : bio_info
          next unless info.present?

          metadata[user_id] = {
            birth_year: info[:birth_year]&.to_i,
            state: info[:state]&.upcase,
          }
        end
        metadata
      end
    end
    # TODO: END ----------------------------------------------------------------

    def age_bins
      current_year = Time.zone.today.year
      bins = Hash.new(0)

      user_metadata.each do |user_id, metadata|
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

    def state_counts
      counts = Hash.new(0)
      user_metadata.each do |user_id, metadata|
        state = metadata[:state]
        next unless state.present?
        counts[state] += 1
      end
      counts.sort.to_h
    end

    # TODO:-----------------------------------------------------------------------
    # modify and and additional fetch for the new queries
    def fetch_sp_redirect_results
      cloudwatch_client.fetch(query: sp_redirect_query, from: time_range.begin, to: time_range.end)
    end

    def fetch_doc_auth_success_bio_info_results
      cloudwatch_client.fetch(
        query: doc_auth_success_bio_info_query, from: time_range.begin,
        to: time_range.end
      )
    end
    # TODO: END -----------------------------------------------------------------------

    # TODO: -----------------------------------------------------------------------
    # split the original query into two
    def sp_redirect_query
      params = {
        issuers: quote(issuers),
        sp_redirect_initiated: quote(Events::SP_REDIRECT_INITIATED),
      }

      format(<<~QUERY, params)
        fields
            properties.user_id as user_id
          , 
        | filter properties.service_provider IN %{issuers}
        | filter (name = %{sp_redirect_initiated} and properties.event_properties.ial = 2 and properties.sp_request.facial_match = 1)
          
        | limit 10000
      QUERY
    end

    def doc_auth_success_bio_info_query
      params = {
        issuers: quote(issuers),
        doc_auth_verify: quote(Events::IDV_DOC_AUTH_PROOFING_RESULTS),
      }

      format(<<~QUERY, params)
        | filter properties.service_provider IN %{issuers}
        | filter (name = %{doc_auth_verify}
        | fields jsonParse(@message) as message
        | unnest message.properties.event_properties into event_properties
        | unnest event_properties.proofing_results into proofing_results
        | unnest proofing_results.biographical_info into biographical_info
        | unnest biographical_info.birth_year into birth_year
        | unnest biographical_info.state_id_jurisdiction into state
        | unnest event_properties.success into success

        | filter success = 1
        | display properties.user_id,  birth_year, state
        | limit 10000
      QUERY
    end

    # TODO: END -----------------------------------------------------------------------

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
