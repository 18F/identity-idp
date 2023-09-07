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
  class MonthlyProofingReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    module Events
      IDV_DOC_AUTH_IMAGE_UPLOAD = 'IdV: doc auth image upload vendor submitted'
      IDV_GPO_ADDRESS_LETTER_REQUESTED = 'IdV: USPS address letter requested'
      USPS_IPP_ENROLLMENT_CREATED = 'USPS IPPaaS enrollment created'
      IDV_FINAL_RESOLUTION = 'IdV: final resolution'
      IDV_PLEASE_CALL_VISITED = 'IdV: Verify please call visited'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Array<String>] issuers
    # @param [Range<Time>] date
    def initialize(
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5,
      issuers: [] # rubocop:disable Lint/UnusedMethodArgument
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

    def to_csv
      CSV.generate do |csv|
        csv << ['report_start', time_range.begin.iso8601]
        csv << ['report_end', time_range.end.iso8601]
        csv << ['report_generated', Date.today.to_s] # rubocop:disable Rails/Date
        csv << ['metric', 'num_users', 'percent']

        start = idv_doc_auth_image_vendor_submitted

        [
          ['image_submitted', idv_doc_auth_image_vendor_submitted],
          ['verified', idv_final_resolution],
          ['not_verified_started_gpo', idv_gpo_address_letter_requested],
          ['not_verified_started_in_person', usps_ipp_enrollment_created],
          ['not_verified_started_fraud_review', idv_please_call_visited],
        ].each do |(label, num)|
          csv << [label, num, num.to_f / start.to_f]
        end
      end
    end

    def idv_doc_auth_image_vendor_submitted
      started_uuids.count
    end

    def idv_final_resolution
      (data[Events::IDV_FINAL_RESOLUTION] & started_uuids).count
    end

    def idv_gpo_address_letter_requested
      ((data[Events::IDV_GPO_ADDRESS_LETTER_REQUESTED] & started_uuids) - verified_uuids).count
    end

    def usps_ipp_enrollment_created
      ((data[Events::USPS_IPP_ENROLLMENT_CREATED] & started_uuids) - verified_uuids).count
    end

    def idv_please_call_visited
      ((data[Events::IDV_PLEASE_CALL_VISITED] & started_uuids) - verified_uuids).count
    end

    def verified_uuids
      data[Events::IDV_FINAL_RESOLUTION]
    end

    def started_uuids
      data[Events::IDV_DOC_AUTH_IMAGE_UPLOAD]
    end

    # Turns query results into a hash keyed by event name, values are a set of unique user IDs
    # for that event
    # @return [Hash<String,Set<String>>]
    def data
      @data ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        # IDEA: maybe there's a block form if this we can do that yields results as it loads them
        # to go slightly faster
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
        idv_final_resolution: quote(Events::IDV_FINAL_RESOLUTION),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
        | filter name in %{event_names}
        | filter (
               name = %{idv_final_resolution}
           and isblank(properties.event_properties.deactivation_reason)
           and properties.event_properties.fraud_review_pending != 1
          )
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
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV, require_issuer: false)

  puts Reporting::MonthlyProofingReport.new(**options).to_csv
end
# rubocop:enable Rails/Output
