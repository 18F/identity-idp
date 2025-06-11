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
      IDV_DOC_AUTH_SOCURE_VERIFICATION_DATA = 'idv_socure_verification_data_requested'
      IDV_DOC_AUTH_VERIFY_RESULTS = 'IdV: doc auth verify proofing results'
      IDV_PHONE_FINDER_RESULTS = 'IdV: phone confirmation vendor'
      IDV_FINAL_RESOLUTION = 'IdV: final resolution'
      GPO_VERIFICATION_SUBMITTED = 'IdV: enter verify by mail code submitted'
      GPO_VERIFICATION_SUBMITTED_OLD = 'IdV: GPO verification submitted'
      USPS_ENROLLMENT_STATUS_UPDATED = 'GetUspsProofingResultsJob: Enrollment status updated'
      FRAUD_REVIEW_PASSED = 'Fraud: Profile review passed'
      FRAUD_REVIEW_REJECT_AUTOMATIC = 'Fraud: Automatic Fraud Rejection'
      FRAUD_REVIEW_REJECT_MANUAL = 'Fraud: Profile review rejected'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    module Results
      # rubocop:disable Layout/LineLength
      IDV_FINAL_RESOLUTION_VERIFIED = 'IdV: final resolution - Verified'
      IDV_FINAL_RESOLUTION_FRAUD_REVIEW = 'IdV: final resolution - Fraud Review Pending'
      IDV_FINAL_RESOLUTION_GPO = 'IdV: final resolution - GPO Pending'
      IDV_FINAL_RESOLUTION_GPO_FRAUD_REVIEW = 'Idv: final resolution - GPO Pending + Fraud Review Pending'
      IDV_FINAL_RESOLUTION_IN_PERSON = 'IdV: final resolution - In Person Proofing'
      IDV_FINAL_RESOLUTION_IN_PERSON_FRAUD_REVIEW = 'IdV: final resolution - In Person Proofing + Fraud Review Pending'
      IDV_FINAL_RESOLUTION_GPO_IN_PERSON = 'IdV: final resolution - GPO Pending + In Person Pending'
      IDV_FINAL_RESOLUTION_GPO_IN_PERSON_FRAUD_REVIEW = 'IdV: final resolution - GPO Pending + In Person Pending + Fraud Review'

      IDV_REJECT_DOC_AUTH = 'IdV Reject: Doc Auth'
      IDV_REJECT_VERIFY = 'IdV Reject: Verify'
      IDV_REJECT_PHONE_FINDER = 'IdV Reject: Phone Finder'
      # rubocop:enable Layout/LineLength
    end

    # Because historically fraud-related events were not tagged with SP data,
    # we need pull these out-of-band events *even if* the are marked as
    # pending fraud review. This allows us to attribute untagged fraud-related
    # events (by matching on user_id). We filter these events for counting
    # purposes, though.
    EVENTS_TO_IGNORE_IF_FRAUD_REVIEW_PENDING = [
      Events::GPO_VERIFICATION_SUBMITTED,
      Events::GPO_VERIFICATION_SUBMITTED_OLD,
      Events::USPS_ENROLLMENT_STATUS_UPDATED,
    ].to_set.freeze

    # @param [Array<String>] issuers
    # @param [Range<Time>] date
    def initialize(
      issuers:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5,
      data: nil,
      cloudwatch_client: nil
    )
      @issuers = issuers
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
      @data = data
      @cloudwatch_client = cloudwatch_client
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    def identity_verification_emailable_report
      EmailableReport.new(
        subtitle: 'Identity Verification Metrics',
        table: as_csv,
        filename: 'identity_verification_metrics',
      )
    end

    # rubocop:disable Layout/LineLength
    def as_csv
      csv = []

      csv << ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"]
      # This needs to be Date.today so it works when run on the command line
      csv << ['Report Generated', Date.today.to_s] # rubocop:disable Rails/Date
      csv << ['Issuer', issuers.join(', ')] if issuers.present?
      csv << []
      csv << ['Metric', '# of Users']
      csv << []
      csv << ['IDV started', idv_started]
      csv << ['Welcome Submitted', idv_doc_auth_welcome_submitted]
      csv << ['Image Submitted', idv_doc_auth_image_vendor_submitted]
      csv << ['Socure Verification Data Requested', idv_doc_auth_socure_verification_data_requested]
      csv << []
      csv << ['Workflow completed', idv_final_resolution]
      csv << ['Workflow completed - With Phone Number', idv_final_resolution_verified]
      csv << ['Workflow completed - With Phone Number - Fraud Review', idv_final_resolution_fraud_review]
      csv << ['Workflow completed - GPO Pending', idv_final_resolution_gpo]
      csv << ['Workflow completed - GPO Pending - Fraud Review', idv_final_resolution_gpo_fraud_review]
      csv << ['Workflow completed - In-Person Pending', idv_final_resolution_in_person]
      csv << ['Workflow completed - In-Person Pending - Fraud Review', idv_final_resolution_in_person_fraud_review]
      csv << ['Workflow completed - GPO + In-Person Pending', idv_final_resolution_gpo_in_person]
      csv << ['Workflow completed - GPO + In-Person Pending - Fraud Review', idv_final_resolution_gpo_in_person_fraud_review]
      csv << []
      csv << ['Fraud review rejected', idv_fraud_rejected]
      csv << ['Successfully Verified', successfully_verified_users]
      csv << ['Successfully Verified - With phone number', idv_final_resolution_verified]
      csv << ['Successfully Verified - With mailed code', gpo_verification_submitted]
      csv << ['Successfully Verified - In Person', usps_enrollment_status_updated]
      csv << ['Successfully Verified - Passed fraud review', fraud_review_passed]
      csv << ['Blanket Proofing Rate (IDV Started to Successfully Verified)', blanket_proofing_rate]
      csv << ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', intent_proofing_rate]
      csv << ['Actual Proofing Rate (Image Submitted to Successfully Verified)', actual_proofing_rate]
      csv << ['Industry Proofing Rate (Verified minus IDV Rejected)', industry_proofing_rate]
    end
    # rubocop:enable Layout/LineLength

    def to_csv
      CSV.generate do |csv|
        as_csv.each do |row|
          csv << row
        end
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

    def blanket_proofing_rate
      successfully_verified_users.to_f / idv_started
    end

    def intent_proofing_rate
      successfully_verified_users.to_f / idv_doc_auth_welcome_submitted
    end

    def actual_proofing_rate
      denom = idv_doc_auth_image_vendor_submitted + idv_doc_auth_socure_verification_data_requested
      successfully_verified_users.to_f / denom
    end

    def industry_proofing_rate
      successfully_verified_users.to_f / (successfully_verified_users + idv_doc_auth_rejected)
    end

    def idv_final_resolution
      data[Events::IDV_FINAL_RESOLUTION].count
    end

    def idv_final_resolution_verified
      data[Results::IDV_FINAL_RESOLUTION_VERIFIED].count
    end

    def idv_final_resolution_fraud_review
      data[Results::IDV_FINAL_RESOLUTION_FRAUD_REVIEW].count
    end

    def idv_final_resolution_gpo
      data[Results::IDV_FINAL_RESOLUTION_GPO].count
    end

    def idv_final_resolution_gpo_fraud_review
      data[Results::IDV_FINAL_RESOLUTION_GPO_FRAUD_REVIEW].count
    end

    def idv_final_resolution_in_person
      data[Results::IDV_FINAL_RESOLUTION_IN_PERSON].count
    end

    def idv_final_resolution_in_person_fraud_review
      data[Results::IDV_FINAL_RESOLUTION_IN_PERSON_FRAUD_REVIEW].count
    end

    def idv_final_resolution_gpo_in_person
      data[Results::IDV_FINAL_RESOLUTION_GPO_IN_PERSON].count
    end

    def idv_final_resolution_gpo_in_person_fraud_review
      data[Results::IDV_FINAL_RESOLUTION_GPO_IN_PERSON_FRAUD_REVIEW].count
    end

    def idv_final_resolution_rate
      idv_final_resolution.to_f / idv_started
    end

    def gpo_verification_submitted
      @gpo_verification_submitted ||= (
        data[Events::GPO_VERIFICATION_SUBMITTED] +
          data[Events::GPO_VERIFICATION_SUBMITTED_OLD]).count
    end

    def usps_enrollment_status_updated
      data[Events::USPS_ENROLLMENT_STATUS_UPDATED].count
    end

    def passed_fraud_review_users
      # Fraud review events may not be tagged with the issuer.
      # When we are filtering by SP, we only count fraud review events where
      # there is another event for the user in the data that _is_ tagged
      # with the issuer.

      users = data[Events::FRAUD_REVIEW_PASSED]

      return users if issuers.nil? || issuers.empty?

      users_with_events_for_any_issuer =
        issuers.each_with_object(Set.new) do |issuer, accumulated_users|
          accumulated_users.merge(data[sp_key(issuer)])
        end

      users & users_with_events_for_any_issuer
    end

    def did_not_pass_fraud_review_users
      result = (
        data[Events::FRAUD_REVIEW_REJECT_AUTOMATIC] +
        data[Events::FRAUD_REVIEW_REJECT_MANUAL]
      )

      issuers&.each do |issuer|
        users_with_events_for_issuer = data[sp_key(issuer)]
        result &= users_with_events_for_issuer
      end

      result
    end

    def successfully_verified_users
      @successfully_verified_users ||= (
        data[Results::IDV_FINAL_RESOLUTION_VERIFIED] +
        data[Events::USPS_ENROLLMENT_STATUS_UPDATED] +
        passed_fraud_review_users +
        data[Events::GPO_VERIFICATION_SUBMITTED] +
        data[Events::GPO_VERIFICATION_SUBMITTED_OLD]
      ).count
    end

    def idv_started
      @idv_started ||=
        (data[Events::IDV_DOC_AUTH_WELCOME] + data[Events::IDV_DOC_AUTH_GETTING_STARTED]).count
    end

    def idv_doc_auth_image_vendor_submitted
      data[Events::IDV_DOC_AUTH_IMAGE_UPLOAD].count
    end

    def idv_doc_auth_socure_verification_data_requested
      data[Events::IDV_DOC_AUTH_SOCURE_VERIFICATION_DATA].count
    end

    def idv_doc_auth_welcome_submitted
      data[Events::IDV_DOC_AUTH_WELCOME_SUBMITTED].count
    end

    def idv_doc_auth_rejected
      @idv_doc_auth_rejected ||= (
        data[Results::IDV_REJECT_DOC_AUTH] +
        data[Results::IDV_REJECT_VERIFY] +
        data[Results::IDV_REJECT_PHONE_FINDER] -
        data[Results::IDV_FINAL_RESOLUTION_VERIFIED] -
        data[Results::IDV_FINAL_RESOLUTION_IN_PERSON]
      ).count
    end

    def idv_fraud_rejected
      did_not_pass_fraud_review_users.count
    end

    def fraud_review_passed
      passed_fraud_review_users.count
    end

    def verified_user_count
      @verified_user_count ||= Reports::BaseReport.transaction_with_timeout do
        Profile.where(active: true).where('verified_at <= ?', time_range.end.end_of_day).count
      end
    end

    # rubocop:disable Layout/LineLength
    # rubocop:disable Metrics/BlockLength
    # Turns query results into a hash keyed by event name, values are a count of unique users
    # for that event
    # @return [Hash<Set<String>>]
    def data
      @data ||= begin
        users = Hash.new do |h, event_name|
          h[event_name] = Set.new
        end

        # IDEA: maybe there's a block form if this we can do that yields results as it loads them
        # to go slightly faster
        fetch_results.each do |row|
          event = row['name']
          user_id = row['user_id']
          success = row['success']
          gpo_verification_pending = row['gpo_verification_pending'] == '1'
          in_person_verification_pending = row['in_person_verification_pending'] == '1'
          fraud_review_pending = row['fraud_review_pending'] == '1'

          ignore_event_for_user =
            fraud_review_pending &&
            EVENTS_TO_IGNORE_IF_FRAUD_REVIEW_PENDING.include?(event)

          users[event] << user_id unless ignore_event_for_user
          users[sp_key(row['service_provider'])] << user_id if row['service_provider'].present?

          case event
          when Events::IDV_FINAL_RESOLUTION
            # We are counting users for each of the final resolution events, but we need to consider
            # the various combinations of pending states and fraud review status.
            # The logic is as follows (listed in the order they are checked):
            #
            # | fraud_review_pending | gpo_verification_pending | in_person_verification_pending | IDV_FINAL_RESOLUTION_      |
            # |----------------------|--------------------------|--------------------------------|----------------------------|
            # | false                | false                    | false                          | VERIFIED                   |
            # | true                 | false                    | false                          | FRAUD_REVIEW               |
            # | false                | true                     | false                          | GPO                        |
            # | true                 | true                     | false                          | GPO_FRAUD_REVIEW           |
            # | false                | false                    | true                           | IN_PERSON                  |
            # | true                 | false                    | true                           | IN_PERSON_FRAUD_REVIEW     |
            # | false                | true                     | true                           | GPO_IN_PERSON              |
            # | true                 | true                     | true                           | GPO_IN_PERSON_FRAUD_REVIEW |
            #
            # The `profile_not_pending` flag indicates that the three pending possibilities are
            # all false AND there is not a deactivation reason recorded.
            users[Results::IDV_FINAL_RESOLUTION_VERIFIED] << user_id if row['profile_not_pending'] == '1'

            if !gpo_verification_pending && !in_person_verification_pending
              users[Results::IDV_FINAL_RESOLUTION_FRAUD_REVIEW] << user_id if fraud_review_pending
            elsif gpo_verification_pending && !in_person_verification_pending
              users[Results::IDV_FINAL_RESOLUTION_GPO] << user_id if !fraud_review_pending
              users[Results::IDV_FINAL_RESOLUTION_GPO_FRAUD_REVIEW] << user_id if fraud_review_pending
            elsif !gpo_verification_pending && in_person_verification_pending
              users[Results::IDV_FINAL_RESOLUTION_IN_PERSON] << user_id if !fraud_review_pending
              users[Results::IDV_FINAL_RESOLUTION_IN_PERSON_FRAUD_REVIEW] << user_id if fraud_review_pending
            elsif gpo_verification_pending && in_person_verification_pending
              users[Results::IDV_FINAL_RESOLUTION_GPO_IN_PERSON] << user_id if !fraud_review_pending
              users[Results::IDV_FINAL_RESOLUTION_GPO_IN_PERSON_FRAUD_REVIEW] << user_id if fraud_review_pending
            end
          when Events::IDV_DOC_AUTH_IMAGE_UPLOAD
            users[Results::IDV_REJECT_DOC_AUTH] << user_id if row['doc_auth_failed_non_fraud'] == '1'
          when Events::IDV_DOC_AUTH_VERIFY_RESULTS
            users[Results::IDV_REJECT_VERIFY] << user_id if success == '0'
          when Events::IDV_PHONE_FINDER_RESULTS
            users[Results::IDV_REJECT_PHONE_FINDER] << user_id if success == '0'
          end
        end

        users
      end
    end
    # rubocop:enable Metrics/BlockLength
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
        fraud_review_passed: quote(Events::FRAUD_REVIEW_PASSED),
        fraud_event_names: quote(
          [
            Events::FRAUD_REVIEW_PASSED,
            Events::FRAUD_REVIEW_REJECT_AUTOMATIC,
            Events::FRAUD_REVIEW_REJECT_MANUAL,
          ],
        ),
        normalized_fraud_review_pending: "(#{[
          # rubocop:disable Layout/LineLength
          'coalesce(properties.event_properties.fraud_review_pending, 0)',
          # NOTE: fraud_pending_reason is present on 'IdV: final resolution' events. For GPO / IPP,
          #       it will be set but the fraud_review_pending flag will be set to 0.
          #       To calculate the 'Workflow completed - GPO Pending - Fraud Review' stat, we
          #       must consider this independently of fraud_review_pending.
          '!isblank(properties.event_properties.fraud_pending_reason)',
          'coalesce(properties.event_properties.fraud_check_failed, 0)',
          'coalesce((ispresent(properties.event_properties.tmx_status) and properties.event_properties.tmx_status in ["threatmetrix_review", "threatmetrix_reject"]), 0)',
          # rubocop:enable Layout/LineLength
        ].join(" OR ")})",
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
          , coalesce(properties.event_properties.success, 0) AS success
          , coalesce(properties.service_provider, properties.event_properties.issuer) AS service_provider
        | filter name in %{event_names}
        | filter (name = %{usps_enrollment_status_updated} and properties.event_properties.passed = 1)
                 or (name != %{usps_enrollment_status_updated})
        | filter (name in %{gpo_verification_submitted} and properties.event_properties.success = 1 and !properties.event_properties.pending_in_person_enrollment)
                 or (name not in %{gpo_verification_submitted})
        | filter (name = %{fraud_review_passed} and properties.event_properties.success = 1)
                 or (name != %{fraud_review_passed})
        #{issuers.present? ? '| filter service_provider IN %{issuers} OR name IN %{fraud_event_names}' : ''}
        | fields
            %{normalized_fraud_review_pending} AS fraud_review_pending
          , coalesce(properties.event_properties.gpo_verification_pending, 0) AS gpo_verification_pending
          , coalesce(properties.event_properties.in_person_verification_pending, 0) AS in_person_verification_pending
          , ispresent(properties.event_properties.deactivation_reason) AS has_other_deactivation_reason
          , properties.event_properties.success = '0' AND properties.event_properties.doc_auth_result NOT IN ['Failed', 'Attention'] AS doc_auth_failed_non_fraud
        | fields
            !fraud_review_pending and !gpo_verification_pending and !in_person_verification_pending and !has_other_deactivation_reason AS profile_not_pending
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

    def sp_key(issuer)
      "sp:#{issuer}"
    end
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV, require_issuer: false)

  puts Reporting::IdentityVerificationReport.new(**options).to_csv
end
# rubocop:enable Rails/Output
