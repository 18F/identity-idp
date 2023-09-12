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

    attr_reader :issuers, :time_range

    module Events
      IDV_DOC_AUTH_WELCOME = 'IdV: doc auth welcome visited'
      IDV_DOC_AUTH_WELCOME_SUBMITTED = 'IdV: doc auth welcome submitted'
      IDV_DOC_AUTH_GETTING_STARTED = 'IdV: doc auth getting_started visited'
      IDV_DOC_AUTH_IMAGE_UPLOAD = 'IdV: doc auth image upload vendor submitted'
      IDV_DOC_AUTH_VERIFY_RESULTS = 'IdV: doc auth verify proofing results'
      IDV_PHONE_FINDER_RESULTS = 'IdV: phone confirmation vendor'
      IDV_FINAL_RESOLUTION = 'IdV: final resolution'
      GPO_VERIFICATION_SUBMITTED = 'IdV: enter verify by mail code submitted'
      GPO_VERIFICATION_SUBMITTED_OLD = 'IdV: GPO verification submitted'
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

      IDV_REJECT_DOC_AUTH = 'IdV Reject: Doc Auth'
      IDV_REJECT_VERIFY = 'IdV Reject: Verify'
      IDV_REJECT_PHONE_FINDER = 'IdV Reject: Phone Finder'
      IDV_REJECT_ANY = 'IdV Reject: Any'
    end

    # @param [Array<String>] issuers
    # @param [Range<Time>] date
    def initialize(
      issuers:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5,
      data: nil
    )
      @issuers = issuers
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
      @data = data
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
        csv << ['Issuer', issuers.join(', ')] if issuers.present?
        csv << []
        csv << ['Metric', '# of Users']
        csv << []
        csv << ['Started IdV Verification', idv_started]
        csv << ['Submitted welcome page', idv_doc_auth_welcome_submitted]
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

    # @param [Reporting::IdentityVerificationReport] other
    # @return [Reporting::IdentityVerificationReport]
    def merge(other)
      self.class.new(
        issuers: (Array(issuers) + Array(other.issuers)).uniq,
        time_range: Range.new(
          [time_range.begin, other.time_range.begin].min,
          [time_range.end, other.time_range.end].max,
        ),
        data: data.merge(other.data) do |_event, old_user_ids, new_user_ids|
          old_user_ids + new_user_ids
        end,
      )
    end

    def idv_final_resolution
      data[Events::IDV_FINAL_RESOLUTION].count
    end

    def idv_final_resolution_verified
      data[Results::IDV_FINAL_RESOLUTION_VERIFIED].count
    end

    def idv_final_resolution_gpo
      data[Results::IDV_FINAL_RESOLUTION_GPO].count
    end

    def idv_final_resolution_in_person
      data[Results::IDV_FINAL_RESOLUTION_IN_PERSON].count
    end

    def idv_final_resolution_fraud_review
      data[Results::IDV_FINAL_RESOLUTION_FRAUD_REVIEW].count
    end

    def idv_doc_auth_rejected
      data[Results::IDV_REJECT_ANY].to_i
    end

    def idv_final_resolution_total_pending
      @idv_final_resolution_total_pending ||=
        (data[Events::IDV_FINAL_RESOLUTION] - data[Results::IDV_FINAL_RESOLUTION_VERIFIED]).count
    end

    def gpo_verification_submitted
      @gpo_verification_submitted ||= (
        data[Events::GPO_VERIFICATION_SUBMITTED] +
          data[Events::GPO_VERIFICATION_SUBMITTED_OLD]).count
    end

    def usps_enrollment_status_updated
      data[Events::USPS_ENROLLMENT_STATUS_UPDATED].count
    end

    def successfully_verified_users
      idv_final_resolution_verified + gpo_verification_submitted + usps_enrollment_status_updated
    end

    def idv_started
      @idv_started ||=
        (data[Events::IDV_DOC_AUTH_WELCOME] + data[Events::IDV_DOC_AUTH_GETTING_STARTED]).count
    end

    def idv_doc_auth_image_vendor_submitted
      data[Events::IDV_DOC_AUTH_IMAGE_UPLOAD].count
    end

    def idv_doc_auth_welcome_submitted
      data[Events::IDV_DOC_AUTH_WELCOME_SUBMITTED].count
    end

    def idv_doc_auth_rejected
      data[Results::IDV_REJECT_ANY].count
    end

    # rubocop:disable Layout/LineLength
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
          event = row['name']
          user_id = row['user_id']
          success = row['success']

          event_users[event] << user_id

          case event
          when Events::IDV_FINAL_RESOLUTION
            event_users[Results::IDV_FINAL_RESOLUTION_VERIFIED] << user_id if row['identity_verified'] == '1'
            event_users[Results::IDV_FINAL_RESOLUTION_GPO] << user_id if row['gpo_verification_pending'] == '1'
            event_users[Results::IDV_FINAL_RESOLUTION_IN_PERSON] << user_id if row['in_person_verification_pending'] == '1'
            event_users[Results::IDV_FINAL_RESOLUTION_FRAUD_REVIEW] << user_id if row['fraud_review_pending'] == '1'
          when Events::IDV_DOC_AUTH_IMAGE_UPLOAD
            event_users[Results::IDV_REJECT_DOC_AUTH] << user_id if success == '0'
          when Events::IDV_DOC_AUTH_VERIFY_RESULTS
            event_users[Results::IDV_REJECT_VERIFY] << user_id if success == '0'
          when Events::IDV_PHONE_FINDER_RESULTS
            event_users[Results::IDV_REJECT_PHONE_FINDER] << user_id if success == '0'
          end
        end

        # remove intermediate failures if user eventually succeeded
        event_users[Results::IDV_REJECT_DOC_AUTH] -= event_users[Results::IDV_FINAL_RESOLUTION_VERIFIED]
        event_users[Results::IDV_REJECT_VERIFY] -= event_users[Results::IDV_FINAL_RESOLUTION_VERIFIED]
        event_users[Results::IDV_REJECT_PHONE_FINDER] -= event_users[Results::IDV_FINAL_RESOLUTION_VERIFIED]

        event_users[Results::IDV_REJECT_ANY] =
          event_users[Results::IDV_REJECT_DOC_AUTH] |
          event_users[Results::IDV_REJECT_VERIFY] |
          event_users[Results::IDV_REJECT_PHONE_FINDER]

        event_users
      end
    end
    # rubocop:enable Layout/LineLength

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuers: issuers.present? && quote(issuers),
        event_names: quote(Events.all_events),
        usps_enrollment_status_updated: quote(Events::USPS_ENROLLMENT_STATUS_UPDATED),
        gpo_verification_submitted: quote(
          [
            Events::GPO_VERIFICATION_SUBMITTED,
            Events::GPO_VERIFICATION_SUBMITTED_OLD,
          ],
        ),
        idv_final_resolution: quote(Events::IDV_FINAL_RESOLUTION),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
          , coalesce(properties.event_properties.success, 0) AS success
        #{issuers.present? ? '| filter properties.service_provider IN %{issuers}' : ''}
        | filter name in %{event_names}
        | filter (name = %{usps_enrollment_status_updated} and properties.event_properties.passed = 1)
                 or (name != %{usps_enrollment_status_updated})
        | filter (name in %{gpo_verification_submitted} and properties.event_properties.success = 1 and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed)
                 or (name not in %{gpo_verification_submitted})
        | fields
            coalesce(properties.event_properties.fraud_review_pending, 0) AS fraud_review_pending
          , coalesce(properties.event_properties.gpo_verification_pending, 0) AS gpo_verification_pending
          , coalesce(properties.event_properties.in_person_verification_pending, 0) AS in_person_verification_pending
          , ispresent(properties.event_properties.deactivation_reason) AS has_other_deactivation_reason
        | fields
            !fraud_review_pending and !gpo_verification_pending and !in_person_verification_pending and !has_other_deactivation_reason AS identity_verified
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
