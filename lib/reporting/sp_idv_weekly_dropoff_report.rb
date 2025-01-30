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
  class SpIdvWeeklyDropoffReport
    attr_reader :issuers, :agency_abbreviation, :time_range

    WeeklyDropoffValues = Struct.new(
      :start_date,
      :end_date,
      :ial2_verified_user_count,
      :non_ial2_verified_user_count,
      :document_authentication_failure_pct,
      :selfie_check_failure_pct,
      :aamva_check_failure_pct,
      :fraud_review_rejected_user_count,
      :gpo_passed_count,
      :fraud_review_passed_count,
      :ipp_passed_count,
      :ial2_getting_started_dropoff,
      :non_ial2_getting_started_dropoff,
      :ial2_document_capture_started_dropoff,
      :non_ial2_document_capture_started_dropoff,
      :ial2_document_captured_dropoff,
      :non_ial2_document_captured_dropoff,
      :ial2_selfie_captured_dropoff,
      :non_ial2_selfie_captured_dropoff,
      :ial2_document_authentication_passed_dropoff,
      :non_ial2_document_authentication_passed_dropoff,
      :ial2_ssn_dropoff,
      :non_ial2_ssn_dropoff,
      :ial2_verify_info_submitted_dropoff,
      :non_ial2_verify_info_submitted_dropoff,
      :ial2_verify_info_passed_dropoff,
      :non_ial2_verify_info_passed_dropoff,
      :ial2_phone_submitted_dropoff,
      :non_ial2_phone_submitted_dropoff,
      :ial2_phone_passed_dropoff,
      :non_ial2_phone_passed_dropoff,
      :ial2_enter_password_dropoff,
      :non_ial2_enter_password_dropoff,
      :ial2_inline_dropoff,
      :non_ial2_inline_dropoff,
      :ial2_verify_by_mail_dropoff,
      :non_ial2_verify_by_mail_dropoff,
      :ial2_fraud_review_dropoff,
      :non_ial2_fraud_review_dropoff,
      :ial2_personal_key_dropoff,
      :non_ial2_personal_key_dropoff,
      :ial2_agency_handoff_dropoff,
      :non_ial2_agency_handoff_dropoff,
      keyword_init: true,
    ) do
      def formatted_date_range
        "#{start_date.to_date} - #{end_date.to_date}"
      end
    end

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

    # rubocop:disable Layout/LineLength
    def as_csv
      [
        ['', *data.map(&:formatted_date_range)],
        ['Overview'],
        ['# of verified users'],
        ['    - IAL2', *data.map(&:ial2_verified_user_count)],
        ['    - Non-IAL2', *data.map(&:non_ial2_verified_user_count)],
        ['# of contact center cases'],
        ['Fraud Checks'],
        ['% of users that failed document authentication check', *data.map(&:document_authentication_failure_pct)],
        ['% of users that failed facial match check (Only for IAL2)', *data.map(&:selfie_check_failure_pct)],
        ['% of users that failed AAMVA attribute match check', *data.map(&:aamva_check_failure_pct)],
        ['# of users that failed LG-99 fraud review', *data.map(&:fraud_review_rejected_user_count)],
        ['User Experience'],
        ['# of verified users via verify-by-mail process (Only for non-IAL2)', *data.map(&:gpo_passed_count)],
        ['# of verified users via fraud redress process', *data.map(&:fraud_review_passed_count)],
        ['# of verified users via in-person proofing (Not currently enabled)', *data.map(&:ipp_passed_count)],
        ['Funnel Analysis'],
        ['% drop-off at Workflow Started'],
        ['    - IAL2', *data.map(&:ial2_getting_started_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_getting_started_dropoff)],
        ['% drop-off at Document Capture Started'],
        ['    - IAL2', *data.map(&:ial2_document_capture_started_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_document_capture_started_dropoff)],
        ['% drop-off at Document Captured'],
        ['    - IAL2', *data.map(&:ial2_document_captured_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_document_captured_dropoff)],
        ['% drop-off at Selfie Captured'],
        ['    - IAL2', *data.map(&:ial2_selfie_captured_dropoff)],
        ['% drop-off at Document Authentication Passed'],
        ['    - IAL2 (with Facial Match)', *data.map(&:ial2_document_authentication_passed_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_document_authentication_passed_dropoff)],
        ['% drop-off at SSN Submitted'],
        ['    - IAL2', *data.map(&:ial2_ssn_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_ssn_dropoff)],
        ['% drop-off at Personal Information Submitted'],
        ['    - IAL2', *data.map(&:ial2_verify_info_submitted_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_verify_info_submitted_dropoff)],
        ['% drop-off at Personal Information Verified'],
        ['    - IAL2', *data.map(&:ial2_verify_info_passed_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_verify_info_passed_dropoff)],
        ['% drop-off at Phone Submitted'],
        ['    - IAL2', *data.map(&:ial2_phone_submitted_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_phone_submitted_dropoff)],
        ['% drop-off at Phone Verified'],
        ['    - IAL2', *data.map(&:ial2_phone_passed_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_phone_passed_dropoff)],
        ['% drop-off at Online Wofklow Completed'],
        ['    - IAL2', *data.map(&:ial2_enter_password_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_enter_password_dropoff)],
        ['% drop-off at Verified for In-Band Users'],
        ['    - IAL2', *data.map(&:ial2_inline_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_inline_dropoff)],
        ['% drop-off at Verified for Verify-by-mail Users'],
        ['    - Non-IAL2', *data.map(&:non_ial2_verify_by_mail_dropoff)],
        ['% drop-off at Verified for Fraud Review Users'],
        ['    - IAL2', *data.map(&:ial2_fraud_review_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_fraud_review_dropoff)],
        ['% drop-off at Personal Key Saved'],
        ['    - IAL2', *data.map(&:ial2_personal_key_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_personal_key_dropoff)],
        ['% drop-off at Agency Handoff Submitted'],
        ['    - IAL2', *data.map(&:ial2_agency_handoff_dropoff)],
        ['    - Non-IAL2', *data.map(&:non_ial2_agency_handoff_dropoff)],
      ]
    end
    # rubocop:enable Layout/LineLength

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
          title: "#{agency_abbreviation} IdV Dropoff Report",
          table: as_csv,
          filename: "#{agency_abbreviation.downcase}_idv_dropoff_report",
        ),
      ]
    end

    def out_of_band_query(inline_event_end_date)
      inline_event_end_date_ms = inline_event_end_date.to_i * 1000
      <<~QUERY
        filter (name = "IdV: final resolution" and properties.service_provider in #{issuers.inspect}) or
                name = "IdV: enter verify by mail code submitted" or
                name = "GetUspsProofingResultsJob: Enrollment status updated" or
                name = "Fraud: Profile review passed"

        | filter (name = "IdV: final resolution" and @timestamp < #{inline_event_end_date_ms} or name != "IdV: final resolution"

        | fields name = "IdV: final resolution" and (
                  !properties.event_properties.gpo_verification_pending and
                  !properties.event_properties.in_person_verification_pending and
                  !ispresent(properties.event_properties.fraud_pending_reason)
                )
                as @verified_inline
        | fields name = "IdV: final resolution" and (
                  properties.event_properties.gpo_verification_pending and
                  !properties.event_properties.in_person_verification_pending and
                  !ispresent(properties.event_properties.fraud_pending_reason)
                )
                as @gpo_pending
        | fields name = "IdV: final resolution" and (
                  properties.event_properties.in_person_verification_pending and
                  !ispresent(properties.event_properties.fraud_pending_reason)
                )
                as @ipp_pending
        | fields name = "IdV: final resolution" and (
                  ispresent(properties.event_properties.fraud_pending_reason)
                )
                as @fraud_pending

        | fields coalesce(name = "IdV: final resolution" and properties.sp_request.facial_match, 0) as is_ial2

        | stats sum(@verified_inline) > 0 as verified_inline,
                sum(@gpo_pending) > 0 and !verified_inline as gpo_pending,
                sum(@ipp_pending) > 0 and !gpo_pending and !verified_inline as ipp_pending,
                sum(@fraud_pending) > 0 and !ipp_pending and !gpo_pending and !verified_inline as fraud_pending,
                sum(name = "IdV: enter verify by mail code submitted" and properties.event_properties.success and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed) > 0 as gpo_passed,
                sum(name = "GetUspsProofingResultsJob: Enrollment status updated" and properties.event_properties.passed and properties.event_properties.tmx_status not in ["threatmetrix_review", "threatmetrix_reject"]) > 0 as ipp_passed,
                sum(name = "Fraud: Profile review passed") > 0 as fraud_review_passed,
                max(is_ial2) + 1 as ial
                by properties.user_id

        | filter verified_inline or gpo_pending or ipp_pending or fraud_pending

        | stats 1 - sum(gpo_passed and gpo_pending) / sum(gpo_pending) as verify_by_mail_dropoff,
                1 - sum(ipp_passed and ipp_pending) / sum(ipp_pending) as in_person_dropoff,
                1 - sum(fraud_review_passed and fraud_pending) / sum(fraud_pending) as fraud_review_dropoff
                by ial
      QUERY
    end

    def sp_session_events_query
      <<~QUERY
        filter (name in [
          "IdV: doc auth welcome visited",
          "IdV: doc auth welcome submitted",
          "IdV: doc auth document_capture visited",
          "Frontend: IdV: front image clicked",
          "Frontend: IdV: back image clicked",
          "Frontend: IdV: front image added",
          "Frontend: IdV: back image added",
          "idv_selfie_image_added",
          "IdV: doc auth image upload vendor submitted",
          "IdV: doc auth ssn visited",
          "IdV: doc auth ssn submitted",
          "IdV: doc auth verify visited",
          "IdV: doc auth verify proofing results",
          "IdV: phone of record visited",
          "IdV: phone confirmation vendor",
          "idv_enter_password_visited",
          "IdV: personal key visited",
          "IdV: personal key submitted",
          "IdV: final resolution",
          "User registration: agency handoff visited",
          "User registration: complete",
          "Fraud: Profile review passed",
          "Fraud: Profile review rejected"
        ] and properties.service_provider in #{issuers.inspect}) or
        (name = "IdV: enter verify by mail code submitted" and properties.event_properties.initiating_service_provider in #{issuers.inspect}) or
        (name = "GetUspsProofingResultsJob: Enrollment status updated" and properties.event_properties.issuer in #{issuers.inspect})

        | fields properties.event_properties.selfie_check_required as selfie_check_required,
                name in ["Frontend: IdV: front image clicked", "Frontend: IdV: back image clicked"] as @document_capture_clicked,
                name in ["Frontend: IdV: front image added", "Frontend: IdV: back image added"] as @document_captured,
                name = "IdV: doc auth image upload vendor submitted" and properties.event_properties.success as @document_authentication_passed

        | fields coalesce(name = "IdV: doc auth welcome visited" and properties.sp_request.facial_match, 0) as is_ial2

        | stats sum(name = "IdV: doc auth welcome visited") > 0 as getting_started_visited,
                sum(name = "IdV: doc auth welcome submitted") > 0 as getting_started_submitted,
                sum(name = "IdV: doc auth document_capture visited") > 0 as document_capture_visited,
                sum(@document_capture_clicked) > 0 as document_capture_clicked,
                sum(@document_captured) > 0 as document_captured,
                sum(name = "idv_selfie_image_added") > 0 or sum(selfie_check_required) == 0 as selfie_captured_or_not_required,
                sum(name = "IdV: doc auth image upload vendor submitted") > 0 as document_authentication_submitted,
                sum(@document_authentication_passed) > 0 as document_authentication_passed,
                sum(name = "IdV: doc auth image upload vendor submitted" and ispresent(properties.event_properties.doc_auth_success) and !properties.event_properties.doc_auth_success) > 0 as doc_auth_failure,
                sum(name = "IdV: doc auth image upload vendor submitted" and properties.event_properties.liveness_checking_required) > 0 as doc_auth_selfie_check_required,
                sum(name = "IdV: doc auth image upload vendor submitted" and properties.event_properties.selfie_status == "fail") > 0 as doc_auth_selfie_check_failure,
                sum(name = "IdV: doc auth ssn visited") > 0 as ssn_visited,
                sum(name = "IdV: doc auth ssn submitted") > 0 as ssn_submitted,
                sum(name = "IdV: doc auth verify visited") > 0 as verify_info_visited,
                sum(name = "IdV: doc auth verify proofing results") > 0 as verify_info_submitted,
                sum(name = "IdV: doc auth verify proofing results" and properties.event_properties.success) > 0 as verify_info_passed,
                sum(name = "IdV: doc auth verify proofing results" and ispresent(properties.event_properties.proofing_results.context.stages.state_id.success) and !properties.event_properties.proofing_results.context.stages.state_id.success and !ispresent(properties.event_properties.proofing_results.context.stages.state_id.exception)) as aamva_failure,
                sum(name = "IdV: phone of record visited") > 0 as phone_visited,
                sum(name = "IdV: phone confirmation vendor") > 0 as phone_submitted,
                sum(name = "IdV: phone confirmation vendor" and properties.event_properties.success) > 0 as phone_passed,
                sum(name = "idv_enter_password_visited") > 0 as enter_password_visited,
                sum(name = "IdV: final resolution") > 0 as enter_password_submitted,
                sum(name = "IdV: personal key visited") > 0 as personal_key_visited,
                sum(name = "IdV: personal key submitted") > 0 as personal_key_submitted,
                sum(name = "User registration: agency handoff visited" and properties.event_properties.ial2) > 0 as agnecy_handoff_visited,
                sum(name = "User registration: complete" and properties.event_properties.ial2) > 0 as agency_handoff_submitted,
                sum(name = "IdV: final resolution" and !properties.event_properties.gpo_verification_pending and !properties.event_properties.in_person_verification_pending and !ispresent(properties.event_properties.fraud_pending_reason)) > 0 as verified_inline,
                sum(name = "Fraud: Profile review passed") > 0 as fraud_review_passed,
                sum(name = "Fraud: Profile review rejected") > 0 as fraud_review_rejected,
                sum(name = "IdV: enter verify by mail code submitted" and properties.event_properties.success and !properties.event_properties.pending_in_person_enrollment and !properties.event_properties.fraud_check_failed) > 0 as gpo_passed,
                sum(name = "GetUspsProofingResultsJob: Enrollment status updated" and properties.event_properties.passed and properties.event_properties.tmx_status not in ["threatmetrix_review", "threatmetrix_reject"]) > 0 as ipp_passed,
                max(is_ial2) + 1 as ial
                by properties.user_id

        | stats 1 - sum(getting_started_submitted) / sum(getting_started_visited) as getting_started_dropoff,
                1 - sum(document_capture_clicked) / sum(document_capture_visited) as document_capture_started_dropoff,
                1 - sum(document_captured) / sum(document_capture_visited) as document_captured_dropoff,
                1 - sum(selfie_captured_or_not_required) / sum(document_capture_visited) as selfie_captured_dropoff,
                1 - sum(document_authentication_passed) / sum(document_capture_visited) as document_authentication_passed_dropoff,
                1 - sum(ssn_submitted) / sum(ssn_visited) as ssn_dropoff,
                1 - sum(verify_info_submitted) / sum(verify_info_visited) as verify_info_submitted_dropoff,
                1 - sum(verify_info_passed) / sum(verify_info_visited) as verify_info_passed_dropoff,
                1 - sum(phone_submitted) / sum(phone_visited) as phone_submitted_dropoff,
                1 - sum(phone_passed) / sum(phone_visited) as phone_passed_dropoff,
                1 - sum(enter_password_submitted) / sum(enter_password_visited) as enter_password_dropoff,
                1 - sum(personal_key_submitted) / sum(personal_key_visited) as personal_key_dropoff,
                1 - sum(agency_handoff_submitted) / sum(agnecy_handoff_visited) as agency_handoff_dropoff,
                sum(doc_auth_failure and !ssn_submitted) as document_authentication_failure_numerator,
                sum(document_authentication_submitted) as document_authentication_failure_denominator,
                sum(doc_auth_selfie_check_failure and !doc_auth_failure and !ssn_submitted) as selfie_check_failure_numerator,
                sum(doc_auth_selfie_check_required) as selfie_check_failure_denominator,
                sum(aamva_failure and !verify_info_passed) as aamva_check_failure_numerator,
                sum(verify_info_submitted) as aamva_check_failure_denominator,
                sum(verified_inline) as verified_inline_count,
                sum(fraud_review_passed) as fraud_review_passed_count,
                sum(fraud_review_rejected) as fraud_review_rejected_count,
                sum(gpo_passed) as gpo_passed_count,
                sum(ipp_passed) as ipp_passed_count
                by ial
      QUERY
    end

    def data
      @data ||= time_range_weekly_ranges.map do |week_time_range|
        get_results_for_week(week_time_range)
      end
    end

    def get_results_for_week(week_time_range)
      sp_session_events_result_by_ial = fetch_results(
        query: sp_session_events_query,
        query_time_range: week_time_range,
      ).index_by { |result_row| result_row['ial'] }

      out_of_band_query_start = week_time_range.begin
      out_of_band_query_end = [week_time_range.end + 4.weeks, Time.zone.now.to_date].min
      out_of_band_inline_end_date = week_time_range.end.end_of_day
      out_of_band_results_by_ial = fetch_results(
        query: out_of_band_query(out_of_band_inline_end_date),
        query_time_range: (out_of_band_query_start..out_of_band_query_end),
      ).index_by { |result_row| result_row['ial'] }

      compute_weekly_dropoff_values(
        sp_session_events_result_by_ial,
        out_of_band_results_by_ial,
        week_time_range,
      )
    end

    # rubocop:disable Layout/LineLength
    def compute_weekly_dropoff_values(
      sp_session_events_result_by_ial, out_of_band_results_by_ial, week_time_range
    )
      WeeklyDropoffValues.new(
        start_date: week_time_range.begin.to_s,
        end_date: week_time_range.end.to_s,
        ial2_verified_user_count: [
          sp_session_events_result_by_ial.dig('2', 'verified_inline_count').to_i,
          sp_session_events_result_by_ial.dig('2', 'fraud_review_passed_count').to_i,
          sp_session_events_result_by_ial.dig('2', 'gpo_passed_count').to_i,
          sp_session_events_result_by_ial.dig('2', 'ipp_passed_count').to_i,
        ].sum.to_s,
        non_ial2_verified_user_count: [
          sp_session_events_result_by_ial.dig('1', 'verified_inline_count').to_i,
          sp_session_events_result_by_ial.dig('1', 'fraud_review_passed_count').to_i,
          sp_session_events_result_by_ial.dig('1', 'gpo_passed_count').to_i,
          sp_session_events_result_by_ial.dig('1', 'ipp_passed_count').to_i,
        ].sum.to_s,
        document_authentication_failure_pct: compute_percentage(
          sp_session_events_result_by_ial.dig('2', 'document_authentication_failure_numerator').to_i + sp_session_events_result_by_ial.dig('1', 'document_authentication_failure_numerator').to_i,
          sp_session_events_result_by_ial.dig('2', 'document_authentication_failure_denominator').to_i + sp_session_events_result_by_ial.dig('1', 'document_authentication_failure_denominator').to_i,
        ),
        selfie_check_failure_pct: compute_percentage(
          sp_session_events_result_by_ial.dig('2', 'selfie_check_failure_numerator').to_i + sp_session_events_result_by_ial.dig('1', 'selfie_check_failure_numerator').to_i,
          sp_session_events_result_by_ial.dig('2', 'selfie_check_failure_denominator').to_i + sp_session_events_result_by_ial.dig('1', 'selfie_check_failure_denominator').to_i,
        ),
        aamva_check_failure_pct: compute_percentage(
          sp_session_events_result_by_ial.dig('2', 'aamva_check_failure_numerator').to_i + sp_session_events_result_by_ial.dig('1', 'aamva_check_failure_numerator').to_i,
          sp_session_events_result_by_ial.dig('2', 'aamva_check_failure_denominator').to_i + sp_session_events_result_by_ial.dig('1', 'aamva_check_failure_denominator').to_i,
        ),
        fraud_review_rejected_user_count: [
          sp_session_events_result_by_ial.dig('2', 'fraud_review_rejected_count').to_i,
          sp_session_events_result_by_ial.dig('1', 'fraud_review_rejected_count').to_i,
        ].sum.to_s,
        gpo_passed_count: [
          sp_session_events_result_by_ial.dig('2', 'gpo_passed_count').to_i,
          sp_session_events_result_by_ial.dig('1', 'gpo_passed_count').to_i,
        ].sum.to_s,
        fraud_review_passed_count: [
          sp_session_events_result_by_ial.dig('2', 'fraud_review_passed_count').to_i,
          sp_session_events_result_by_ial.dig('1', 'fraud_review_passed_count').to_i,
        ].sum.to_s,
        ipp_passed_count: [
          sp_session_events_result_by_ial.dig('2', 'ipp_passed_count').to_i,
          sp_session_events_result_by_ial.dig('1', 'ipp_passed_count').to_i,
        ].sum.to_s,
        ial2_getting_started_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'getting_started_dropoff').to_f),
        non_ial2_getting_started_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'getting_started_dropoff').to_f),
        ial2_document_capture_started_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'document_capture_started_dropoff').to_f),
        non_ial2_document_capture_started_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'document_capture_started_dropoff').to_f),
        ial2_document_captured_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'document_captured_dropoff').to_f),
        non_ial2_document_captured_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'document_captured_dropoff').to_f),
        ial2_selfie_captured_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'selfie_captured_dropoff').to_f),
        non_ial2_selfie_captured_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'selfie_captured_dropoff').to_f),
        ial2_document_authentication_passed_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'document_authentication_passed_dropoff').to_f),
        non_ial2_document_authentication_passed_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'document_authentication_passed_dropoff').to_f),
        ial2_ssn_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'ssn_dropoff').to_f),
        non_ial2_ssn_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'ssn_dropoff').to_f),
        ial2_verify_info_submitted_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'verify_info_submitted_dropoff').to_f),
        non_ial2_verify_info_submitted_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'verify_info_submitted_dropoff').to_f),
        ial2_verify_info_passed_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'verify_info_passed_dropoff').to_f),
        non_ial2_verify_info_passed_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'verify_info_passed_dropoff').to_f),
        ial2_phone_submitted_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'phone_submitted_dropoff').to_f),
        non_ial2_phone_submitted_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'phone_submitted_dropoff').to_f),
        ial2_phone_passed_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'phone_passed_dropoff').to_f),
        non_ial2_phone_passed_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'phone_passed_dropoff').to_f),
        ial2_enter_password_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'enter_password_dropoff').to_f),
        non_ial2_enter_password_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'enter_password_dropoff').to_f),
        ial2_inline_dropoff: format_percentage(0.0),
        non_ial2_inline_dropoff: format_percentage(0.0),
        ial2_verify_by_mail_dropoff: format_percentage(out_of_band_results_by_ial.dig('2', 'verify_by_mail_dropoff').to_f),
        non_ial2_verify_by_mail_dropoff: format_percentage(out_of_band_results_by_ial.dig('1', 'verify_by_mail_dropoff').to_f),
        ial2_fraud_review_dropoff: format_percentage(out_of_band_results_by_ial.dig('2', 'fraud_review_dropoff').to_f),
        non_ial2_fraud_review_dropoff: format_percentage(out_of_band_results_by_ial.dig('1', 'fraud_review_dropoff').to_f),
        ial2_personal_key_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'personal_key_dropoff').to_f),
        non_ial2_personal_key_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'personal_key_dropoff').to_f),
        ial2_agency_handoff_dropoff: format_percentage(sp_session_events_result_by_ial.dig('2', 'agency_handoff_dropoff').to_f),
        non_ial2_agency_handoff_dropoff: format_percentage(sp_session_events_result_by_ial.dig('1', 'agency_handoff_dropoff').to_f),
      )
    end
    # rubocop:enable Layout/LineLength

    def compute_percentage(numerator, denominator)
      return format_percentage(0.0) if denominator == 0

      format_percentage(numerator.to_f / denominator.to_f)
    end

    def format_percentage(value)
      return '0.0%' if value.blank?
      (value * 100).round(2).to_s + '%'
    end

    def time_range_weekly_ranges
      start_date = time_range.begin.beginning_of_week(:sunday)
      end_date = time_range.end.end_of_week(:sunday)
      (start_date..end_date).step(7).map do |week_start|
        week_start.all_week(:sunday)
      end
    end

    def fetch_results(query:, query_time_range:)
      cloudwatch_client.fetch(
        query:,
        from: query_time_range.begin.beginning_of_day,
        to: query_time_range.end.end_of_day,
      )
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
