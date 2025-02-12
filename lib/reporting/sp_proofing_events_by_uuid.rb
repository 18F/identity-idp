# frozen_string_literal: true

require 'reporting/cloudwatch_client'
require 'reporting/cloudwatch_query_quoting'

module Reporting
  class SpProofingEventsByUuid
    attr_reader :issuers, :agency_abbreviation, :time_range

    def initialize(
      issuers:,
      agency_abbreviation:,
      time_range:,
      verbose: false,
      progress: false,
      cloudwatch_client: nil
    )
      @issuers = issuers
      @agency_abbreviation = agency_abbreviation
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @cloudwatch_client = cloudwatch_client
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    def query(after_row:)
      base_query = <<~QUERY
        filter properties.service_provider in #{issuers.inspect} or
              (name = "IdV: enter verify by mail code submitted" and properties.event_properties.initiating_service_provider in #{issuers.inspect})
        | filter name in [
          "IdV: doc auth welcome visited",
          "IdV: doc auth document_capture visited",
          "Frontend: IdV: front image added",
          "Frontend: IdV: back image added",
          "idv_selfie_image_added",
          "IdV: doc auth image upload vendor submitted",
          "IdV: doc auth ssn submitted",
          "IdV: doc auth verify proofing results",
          "IdV: phone confirmation form",
          "IdV: phone confirmation vendor",
          "IdV: final resolution",
          "IdV: enter verify by mail code submitted",
          "Fraud: Profile review passed",
          "Fraud: Profile review rejected",
          "User registration: agency handoff visited",
          "SP redirect initiated"
        ]

        | fields coalesce(name = "Fraud: Profile review passed" and properties.event_properties.success, 0) * properties.event_properties.profile_age_in_seconds as fraud_review_profile_age_in_seconds,
                coalesce(name = "IdV: enter verify by mail code submitted" and properties.event_properties.success and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed, 0) * properties.event_properties.profile_age_in_seconds  as gpo_profile_age_in_seconds,
                fraud_review_profile_age_in_seconds + gpo_profile_age_in_seconds as profile_age_in_seconds

        | stats sum(name = "IdV: doc auth welcome visited") > 0 as workflow_started,
                sum(name = "IdV: doc auth document_capture visited") > 0 as doc_auth_started,
                sum(name = "Frontend: IdV: front image added") > 0 and sum(name = "Frontend: IdV: back image added") > 0 as document_captured,
                sum(name = "idv_selfie_image_added") > 0 as selfie_captured,
                sum(name = "IdV: doc auth image upload vendor submitted" and properties.event_properties.success) > 0 as doc_auth_passed,
                sum(name = "IdV: doc auth ssn submitted") > 0 as ssn_submitted,
                sum(name = "IdV: doc auth verify proofing results") > 0 as personal_info_submitted,
                sum(name = "IdV: doc auth verify proofing results" and properties.event_properties.success) > 0 as personal_info_verified,
                sum(name = "IdV: phone confirmation form") > 0 as phone_submitted,
                sum(name = "IdV: phone confirmation vendor" and properties.event_properties.success) > 0 as phone_verified,
                sum(name = "IdV: final resolution") > 0 as online_workflow_completed,
                sum(name = "IdV: final resolution" and !properties.event_properties.gpo_verification_pending and !properties.event_properties.in_person_verification_pending and !coalesce(properties.event_properties.fraud_pending_reason, 0)) > 0 as verified_in_band,
                sum(name = "IdV: enter verify by mail code submitted" and properties.event_properties.success and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed) > 0 as verified_by_mail,
                sum(name = "Fraud: Profile review passed" and properties.event_properties.success) > 0 as verified_fraud_review,
                max(profile_age_in_seconds) as out_of_band_verification_pending_seconds,
                sum(name = "User registration: agency handoff visited" and properties.event_properties.ial2) > 0 as agency_handoff,
                sum(name = "SP redirect initiated" and properties.event_properties.ial == 2) > 0 as sp_redirect,
                toMillis(min(@timestamp)) as first_event
                by properties.user_id as login_uuid
        | filter workflow_started > 0 or verified_by_mail > 0 or verified_fraud_review > 0
        | limit 10000
        | sort first_event asc
      QUERY
      return base_query if after_row.nil?

      base_query + " | filter first_event > #{after_row['first_event']}"
    end

    def as_csv
      csv = []
      csv << ['Date Range', "#{time_range.begin.to_date} - #{time_range.end.to_date}"]
      csv << csv_header
      data.each do |result_row|
        csv << result_row
      end
      csv.compact
    end

    def to_csv
      CSV.generate do |csv|
        as_csv.each do |row|
          csv << row
        end
      end
    end

    def as_emailable_reports
      [
        EmailableReport.new(
          title: "#{agency_abbreviation} Proofing Events By UUID",
          table: as_csv,
          filename: "#{agency_abbreviation.downcase}_proofing_events_by_uuid",
        ),
      ]
    end

    def csv_header
      [
        'UUID',
        'Workflow Started',
        'Documnet Capture Started',
        'Document Captured',
        'Selfie Captured',
        'Document Authentication Passed',
        'SSN Submitted',
        'Personal Information Submitted',
        'Personal Information Verified',
        'Phone Submitted',
        'Phone Verified',
        'Verification Workflow Complete',
        'Identity Verified for In-Band Users',
        'Identity Verified for Verify-By-Mail Users',
        'Identity Verified for Fraud Review Users',
        'Out-of-Band Verification Pending Seconds',
        'Agency Handoff Visited',
        'Agency Handoff Submitted',
      ]
    end

    def data
      return @data if defined? @data

      login_uuid_data ||= fetch_results.map do |result_row|
        process_result_row(result_row)
      end
      login_uuid_to_agency_uuid_map = build_uuid_map(login_uuid_data.map(&:first))

      @data = login_uuid_data.map do |row|
        login_uuid, *row_data = row
        agency_uuid = login_uuid_to_agency_uuid_map[login_uuid]
        next if agency_uuid.nil?
        [agency_uuid, *row_data]
      end.compact
    end

    def process_result_row(result_row)
      [
        result_row['login_uuid'],
        result_row['workflow_started'] == '1',
        result_row['doc_auth_started'] == '1',
        result_row['document_captured'] == '1',
        result_row['selfie_captured'] == '1',
        result_row['doc_auth_passed'] == '1',
        result_row['ssn_submitted'] == '1',
        result_row['personal_info_submitted'] == '1',
        result_row['personal_info_verified'] == '1',
        result_row['phone_submitted'] == '1',
        result_row['phone_verified'] == '1',
        result_row['online_workflow_completed'] == '1',
        result_row['verified_in_band'] == '1',
        result_row['verified_by_mail'] == '1',
        result_row['verified_fraud_review'] == '1',
        result_row['out_of_band_verification_pending_seconds'].to_i,
        result_row['agency_handoff'] == '1',
        result_row['sp_redirect'] == '1',
      ]
    end

    # rubocop:disable Rails/FindEach
    # Use of `find` instead of `find_each` here is safe since we are already batching the UUIDs
    # that go into the query
    def build_uuid_map(uuids)
      uuid_map = Hash.new

      uuids.each_slice(1000) do |uuid_slice|
        Reports::BaseReport.transaction_with_timeout do
          AgencyIdentity.joins(:user).where(
            agency:,
            users: { uuid: uuid_slice },
          ).each do |agency_identity|
            uuid_map[agency_identity.user.uuid] = agency_identity.uuid
          end
        end
      end

      uuid_map
    end
    # rubocop:enable Rails/FindEach

    def agency
      @agency ||= begin
        record = Agency.find_by(abbreviation: agency_abbreviation)
        raise "Unable to find agency with abbreviation: #{agency_abbreviation}" if record.nil?
        record
      end
    end

    def fetch_results(after_row: nil)
      results = cloudwatch_client.fetch(
        query: query(after_row:),
        from: time_range.begin.beginning_of_day,
        to: time_range.end.end_of_day,
      )
      return results if results.count < 10000
      results + fetch_results(after_row: results.last)
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: 1,
        ensure_complete_logs: false,
        slice_interval: 100.years,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end
  end
end
