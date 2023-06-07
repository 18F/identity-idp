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

    # @param [Range<Time>] date
    def initialize(
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5,
      issuer: nil # rubocop:disable Lint/UnusedMethodArgument
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
        csv << ['report_generated', Date.today.to_s]
        csv << ['metric', 'num_users', 'percent']

        start = idv_doc_auth_image_vendor_submitted

        [
          ['image_submitted', idv_doc_auth_image_vendor_submitted],
          ['verified', idv_final_resolution],
          ['started_gpo', idv_gpo_address_letter_requested],
          ['started_in_person', usps_ipp_enrollment_created],
          ['started_fraud_review', idv_please_call_visited]
        ].each do |(label, num)|
          csv << [label, num, num.to_f / start.to_f]
        end
      end
      # rubocop:enable Metrics/LineLength
    end

    def idv_doc_auth_image_vendor_submitted
      data[Events::IDV_DOC_AUTH_IMAGE_UPLOAD].to_i
    end

    def idv_final_resolution
      data[Events::IDV_FINAL_RESOLUTION].to_i
    end

    def idv_gpo_address_letter_requested
      data[Events::IDV_GPO_ADDRESS_LETTER_REQUESTED].to_i
    end

    def usps_ipp_enrollment_created
      data[Events::USPS_IPP_ENROLLMENT_CREATED].to_i
    end

    def idv_please_call_visited
      data[Events::IDV_PLEASE_CALL_VISITED].to_i
    end

    # Turns query results into a hash keyed by event name, values are a count of unique users
    # for that event
    # @return [Hash<String,Integer>]
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

        event_users.transform_values(&:count)
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
        | filter (name = %{idv_final_resolution} and isblank(properties.event_properties.deactivation_reason))
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
