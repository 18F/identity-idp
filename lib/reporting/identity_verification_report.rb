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
  class IdentityVerificationReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuer, :time_range

    module Events
      IDV_DOC_AUTH_IMAGE_UPLOAD = 'IdV: doc auth image upload vendor submitted'
      IDV_GPO_ADDRESS_LETTER_REQUESTED = 'IdV: USPS address letter requested'
      USPS_IPP_ENROLLMENT_CREATED = 'USPS IPPaaS enrollment created'
      IDV_FINAL_RESOLUTION = 'IdV: final resolution'
      GPO_VERIFICATION_SUBMITTED = 'IdV: GPO verification submitted'
      USPS_ENROLLMENT_STATUS_UPDATED = 'GetUspsProofingResultsJob: Enrollment status updated'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [String] isssuer
    # @param [Range<Time>] date
    def initialize(
      issuer:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5
    )
      @issuer = issuer
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
        csv << ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"]
        csv << ['Report Generated', Date.today.to_s] # rubocop:disable Rails/Date
        csv << ['Issuer', issuer]
        csv << []
        csv << ['Metric', '# of Users']
        csv << ['Started IdV Verification', idv_doc_auth_image_vendor_submitted]
        csv << ['Incomplete Users', incomplete_users]
        csv << ['Address Confirmation Letters Requested', idv_gpo_address_letter_requested]
        csv << ['Started In-Person Verification', usps_ipp_enrollment_created]
        csv << ['Alternative Process Users', alternative_process_users]
        csv << ['Success through Online Verification', idv_final_resolution]
        csv << ['Success through Address Confirmation Letters', gpo_verification_submitted]
        csv << ['Success through In-Person Verification', usps_enrollment_status_updated]
        csv << ['Successfully Verified Users', successfully_verified_users]
      end
    end

    def incomplete_users
      idv_doc_auth_image_vendor_submitted - successfully_verified_users - alternative_process_users
    end

    def idv_gpo_address_letter_requested
      data[Events::IDV_GPO_ADDRESS_LETTER_REQUESTED].to_i
    end

    def usps_ipp_enrollment_created
      data[Events::USPS_IPP_ENROLLMENT_CREATED].to_i
    end

    def alternative_process_users
      [
        idv_gpo_address_letter_requested,
        usps_ipp_enrollment_created,
        -gpo_verification_submitted,
        -usps_enrollment_status_updated,
      ].sum
    end

    def idv_final_resolution
      data[Events::IDV_FINAL_RESOLUTION].to_i
    end

    def gpo_verification_submitted
      data[Events::GPO_VERIFICATION_SUBMITTED].to_i
    end

    def usps_enrollment_status_updated
      data[Events::USPS_ENROLLMENT_STATUS_UPDATED].to_i
    end

    def successfully_verified_users
      idv_final_resolution + gpo_verification_submitted + usps_enrollment_status_updated
    end

    def idv_doc_auth_image_vendor_submitted
      data[Events::IDV_DOC_AUTH_IMAGE_UPLOAD].to_i
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
        issuer: quote(issuer),
        event_names: quote(Events.all_events),
        usps_enrollment_status_updated: quote(Events::USPS_ENROLLMENT_STATUS_UPDATED),
        gpo_verification_submitted: quote(Events::GPO_VERIFICATION_SUBMITTED),
        idv_final_resolution: quote(Events::IDV_FINAL_RESOLUTION),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
        | filter properties.service_provider = %{issuer}
        | filter name in %{event_names}
        | filter (name = %{usps_enrollment_status_updated} and properties.event_properties.passed = 1)
                 or (name != %{usps_enrollment_status_updated})
        | filter (name = %{gpo_verification_submitted} and properties.event_properties.success = 1)
                 or (name != %{gpo_verification_submitted})
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
  options = Reporting::CommandLineOptions.new.parse!(ARGV)

  puts Reporting::IdentityVerificationReport.new(**options).to_csv
end
# rubocop:enable Rails/Output
