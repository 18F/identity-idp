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
      IDV_DOC_AUTH_WELCOME = 'IdV: doc auth welcome visited'
      IDV_DOC_AUTH_GETTING_STARTED = 'IdV: doc auth getting_started visited'
      IDV_DOC_AUTH_IMAGE_UPLOAD = 'IdV: doc auth image upload vendor submitted'
      IDV_FINAL_RESOLUTION = 'IdV: final resolution'
      GPO_VERIFICATION_SUBMITTED = 'IdV: GPO verification submitted'
      USPS_ENROLLMENT_STATUS_UPDATED = 'GetUspsProofingResultsJob: Enrollment status updated'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    module Results
      IDV_FINAL_RESOLUTION_VERIFIED = 'IdV: final resolution - Verified'
      IDV_FINAL_RESOLUTION_FRAUD_REVIEW = 'IdV: final resolution - Fraud Review Pending'
      IDV_FINAL_RESOLUTION_GPO = 'IdV: final resolution - GPO Pending'
      IDV_FINAL_RESOLUTION_IN_PERSON = 'IdV: final resolution - In Person Proofing'
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
        csv << ['Issuer', issuer] if issuer.present?
        csv << []
        csv << ['Metric', '# of Users']
        csv << []
        csv << ['Started IdV Verification', idv_started]
        csv << ['Images uploaded', idv_doc_auth_image_vendor_submitted]
        csv << []
        csv << ['Workflow completed', idv_final_resolution]
        csv << ['Workflow completed - Verified', idv_final_resolution_verified]
        csv << ['Workflow completed - Total Pending', idv_final_resolution_total_pending]
        csv << ['Workflow completed - GPO Pending', idv_final_resolution_gpo]
        csv << ['Workflow completed - In-Person Pending', idv_final_resolution_in_person]
        csv << ['Workflow completed - Fraud Review Pending', idv_final_resolution_fraud_review]
        csv << []
        csv << ['Succesfully verified', successfully_verified_users]
        csv << ['Succesfully verified - Inline', idv_final_resolution_verified]
        csv << ['Succesfully verified - GPO Code Entry', gpo_verification_submitted]
        csv << ['Succesfully verified - In Person', usps_enrollment_status_updated]
      end
    end

    def idv_final_resolution
      data[Events::IDV_FINAL_RESOLUTION].to_i
    end

    def idv_final_resolution_verified
      data[Results::IDV_FINAL_RESOLUTION_VERIFIED].to_i
    end

    def idv_final_resolution_gpo
      data[Results::IDV_FINAL_RESOLUTION_GPO].to_i
    end

    def idv_final_resolution_in_person
      data[Results::IDV_FINAL_RESOLUTION_IN_PERSON].to_i
    end

    def idv_final_resolution_fraud_review
      data[Results::IDV_FINAL_RESOLUTION_FRAUD_REVIEW].to_i
    end

    def idv_final_resolution_total_pending
      idv_final_resolution - idv_final_resolution_verified
    end

    def gpo_verification_submitted
      data[Events::GPO_VERIFICATION_SUBMITTED].to_i
    end

    def usps_enrollment_status_updated
      data[Events::USPS_ENROLLMENT_STATUS_UPDATED].to_i
    end

    def successfully_verified_users
      idv_final_resolution_verified + gpo_verification_submitted + usps_enrollment_status_updated
    end

    def idv_started
      [
        data[Events::IDV_DOC_AUTH_WELCOME].to_i,
        data[Events::IDV_DOC_AUTH_GETTING_STARTED].to_i,
      ].sum
    end

    def idv_doc_auth_image_vendor_submitted
      data[Events::IDV_DOC_AUTH_IMAGE_UPLOAD].to_i
    end

    # Turns query results into a hash keyed by event name, values are a count of unique users
    # for that event
    # @return [Hash<Set<String>>]
    def data
      @data ||= begin
        event_users = Hash.new do |h, event_name|
          h[event_name] = Set.new
        end

        # IDEA: maybe there's a block form if this we can do that yields results as it loads them
        # to go slightly faster
        fetch_results.each do |row|
          event_users[row['name']] << row['user_id']

          if row['name'] == Events::IDV_FINAL_RESOLUTION
            if row['identity_verified'] == '1'
              event_users[Results::IDV_FINAL_RESOLUTION_VERIFIED] << row['user_id']
            end
            if row['gpo_verification_pending'] == '1'
              event_users[Results::IDV_FINAL_RESOLUTION_GPO] << row['user_id']
            end
            if row['in_person_verification_pending'] == '1'
              event_users[Results::IDV_FINAL_RESOLUTION_IN_PERSON] << row['user_id']
            end
            if row['fraud_review_pending'] == '1'
              event_users[Results::IDV_FINAL_RESOLUTION_FRAUD_REVIEW] << row['user_id']
            end
          end
        end

        event_users.transform_values(&:count)
      end
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuer: issuer && quote(issuer),
        event_names: quote(Events.all_events),
        usps_enrollment_status_updated: quote(Events::USPS_ENROLLMENT_STATUS_UPDATED),
        gpo_verification_submitted: quote(Events::GPO_VERIFICATION_SUBMITTED),
        idv_final_resolution: quote(Events::IDV_FINAL_RESOLUTION),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
        #{issuer.present? ? '| filter properties.service_provider = %{issuer}' : ''}
        | filter name in %{event_names}
        | filter (name = %{usps_enrollment_status_updated} and properties.event_properties.passed = 1)
                 or (name != %{usps_enrollment_status_updated})
        | filter (name = %{gpo_verification_submitted} and properties.event_properties.success = 1 and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed)
                 or (name != %{gpo_verification_submitted})
        | fields
            coalesce(properties.event_properties.fraud_review_pending, 0) AS fraud_review_pending
          , coalesce(properties.event_properties.gpo_verification_pending, 0) AS gpo_verification_pending
          , coalesce(properties.event_properties.in_person_verification_pending, 0) AS in_person_verification_pending
          , ispresent(properties.event_properties.deactivation_reason) AS has_legacy_deactivation_reason
        | fields
            !fraud_review_pending and !gpo_verification_pending and !in_person_verification_pending and !has_legacy_deactivation_reason AS identity_verified
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

  puts Reporting::IdentityVerificationReport.new(**options).to_csv
end
# rubocop:enable Rails/Output
