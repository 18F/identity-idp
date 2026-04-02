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
          properties.event_properties.issuer in #{issuers.inspect} or
          (name = "IdV: enter verify by mail code submitted" and properties.event_properties.initiating_service_provider in #{issuers.inspect})
        | filter name in [
            "IdV: doc auth welcome visited",
            "IdV: doc auth document_capture visited",
            "idv_doc_auth_socure_webhook_received",
            "idv_socure_verification_data_requested",
            "IdV: doc auth ssn submitted",
            "IdV: doc auth verify proofing results",
            "IdV: phone confirmation form",
            "IdV: phone confirmation vendor",
            "USPS IPPaaS enrollment created",
            "IdV: final resolution",
            "GetUspsProofingResultsJob: Enrollment status updated",
            "idv_profile_activated",
            "IdV: enter verify by mail code submitted",
            "Fraud: Profile review passed",
            "Fraud: Profile review rejected",
            "User registration: agency handoff visited",
            "SP redirect initiated"
        ]

        | fields
            coalesce(name = "Fraud: Profile review passed" and properties.event_properties.success, 0) * properties.event_properties.profile_age_in_seconds as fraud_review_profile_age_in_seconds,
            coalesce(name = "IdV: enter verify by mail code submitted" and properties.event_properties.success and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed, 0) * properties.event_properties.profile_age_in_seconds as gpo_profile_age_in_seconds,
            coalesce(name = "GetUspsProofingResultsJob: Enrollment status updated", 0) * properties.event_properties.profile_age_in_seconds as ipp_profile_age_in_seconds,
            fraud_review_profile_age_in_seconds + gpo_profile_age_in_seconds + ipp_profile_age_in_seconds as profile_age_in_seconds,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.reason, null) as ipp_update_reason_,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.failure_reason, null) as ipp_failure_reason_,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.transaction_end_date_time, null) as ipp_update_time_,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.primary_id_type, null) as ipp_primary_id_type_,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.secondary_id_type, null) as ipp_secondary_id_type_,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.proofing_post_office, null) as ipp_post_office_name_,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.proofing_city, null) as ipp_post_office_city_,
            if(name = "GetUspsProofingResultsJob: Enrollment status updated", properties.event_properties.proofing_state, null) as ipp_post_office_state_

        | stats 
            sum(name = "IdV: doc auth welcome visited") > 0 as workflow_started,
            sum(name = "IdV: doc auth document_capture visited") > 0 as doc_auth_started,
            sum(name = "idv_doc_auth_socure_webhook_received" and properties.event_properties.event_type = 'DOCUMENT_FRONT_UPLOADED') > 0 as document_captured,
            sum(name = "idv_doc_auth_socure_webhook_received" and properties.event_properties.event_type = 'DOCUMENT_SELFIE_UPLOADED') > 0 as selfie_captured,
            sum((name = "IdV: doc auth image upload vendor submitted" and properties.event_properties.success) or (name = "idv_socure_verification_data_requested" and properties.event_properties.success)) > 0 as doc_auth_passed,
            sum(name = "IdV: doc auth ssn submitted") > 0 as ssn_submitted,
            sum(name = "IdV: doc auth verify proofing results") > 0 as personal_info_submitted,
            sum(name = "IdV: doc auth verify proofing results" and properties.event_properties.success) > 0 as personal_info_verified,
            sum(name = "IdV: phone confirmation form") > 0 as phone_submitted,
            sum(name = "IdV: phone confirmation vendor" and properties.event_properties.success) > 0 as phone_verified,
            sum(name = "IdV: final resolution") > 0 as online_workflow_completed,
            sum(name = "IdV: final resolution" and !properties.event_properties.gpo_verification_pending and !properties.event_properties.in_person_verification_pending and !coalesce(properties.event_properties.fraud_pending_reason, 0)) > 0 as verified_in_band,
            sum(name = "USPS IPPaaS enrollment created" and properties.event_properties.opted_in_to_in_person_proofing) > 0 as ipp_started,
            sum(name = "GetUspsProofingResultsJob: Enrollment status updated") > 0 as ipp_updated,
            earliest(ipp_update_reason_) as ipp_update_reason,
            earliest(ipp_update_time_) as ipp_update_time,
            sum(name = "GetUspsProofingResultsJob: Enrollment status updated" and properties.event_properties.passed) > 0 as ipp_passed,
            earliest(ipp_failure_reason_) as ipp_failure_reason,
            sum(name = "GetUspsProofingResultsJob: Enrollment status updated" and properties.event_properties.fraud_suspected) > 0 as ipp_fraud_suspected,
            earliest(ipp_primary_id_type_) as ipp_primary_id_type,
            earliest(ipp_secondary_id_type_) as ipp_secondary_id_type,
            earliest(ipp_post_office_name_) as ipp_post_office_name,
            earliest(ipp_post_office_city_) as ipp_post_office_city,
            earliest(ipp_post_office_state_) as ipp_post_office_state,
            sum(name = "idv_profile_activated" and properties.event_properties.active_profile_idv_level = 'in_person') > 0 as verified_by_ipp,
            sum(name = "IdV: enter verify by mail code submitted" and properties.event_properties.success and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed) > 0 as verified_by_mail,
            sum(name = "Fraud: Profile review passed" and properties.event_properties.success) > 0 as verified_fraud_review,
            max(profile_age_in_seconds) as out_of_band_verification_pending_seconds,
            sum(name = "User registration: agency handoff visited" and properties.event_properties.ial2) > 0 as agency_handoff,
            sum(name = "SP redirect initiated" and properties.event_properties.ial == 2) > 0 as sp_redirect,
            sortsFirst(properties.service_provider) as issuer,
            sortsFirst(properties.sp_request.app_differentiator) as app_differentiator,
            toMillis(min(@timestamp)) as first_event
            by properties.user_id as login_uuid
        | filter workflow_started > 0 or ipp_updated > 0 or verified_by_mail > 0 or verified_fraud_review > 0
        | limit 10000
        | sort first_event asc
      QUERY
      return base_query if after_row.nil?

      base_query + " | filter first_event > #{after_row['first_event']}"
    end

    def as_csv
      csv = []
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
        'uuid',
        'issuer',
        'app differentiator',
        'workflow started',
        'document capture started',
        'document captured',
        'selfie captured',
        'document authentication passed',
        'ssn submitted',
        'personal information submitted',
        'personal information verified',
        'phone submitted',
        'phone verified',
        'verification workflow complete',
        'identity verified for in-band user',
        'ipp started',
        'ipp updated',
        'ipp update reason',
        'ipp update time',
        'ipp passed',
        'ipp failure reason',
        'ipp fraud suspected',
        'ipp primary id type',
        'ipp secondary id type',
        'ipp post office name',
        'ipp post office city',
        'ipp post office state',
        'identity verified for ipp user',
        'identity verified for verify-by-mail user',
        'identity verified for fraud review user',
        'out-of-band verification pending seconds',
        'agency handoff visited',
        'agency handoff submitted',
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
        result_row['issuer'],
        result_row['app_differentiator'],
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
        result_row['ipp_started'] == '1',
        result_row['ipp_updated'] == '1',
        result_row['ipp_update_reason'],
        result_row['ipp_update_time'],
        result_row['ipp_passed'] == '1',
        result_row['ipp_failure_reason'],
        result_row['ipp_fraud_suspected'] == '1',
        result_row['ipp_primary_id_type'],
        result_row['ipp_secondary_id_type'],
        result_row['ipp_post_office_name'],
        result_row['ipp_post_office_city'],
        result_row['ipp_post_office_state'],
        result_row['verified_by_ipp'] == '1',
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
