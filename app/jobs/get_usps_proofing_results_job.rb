# frozen_string_literal: true

class GetUspsProofingResultsJob < ApplicationJob
  MILLISECONDS_PER_SECOND = 1000.0 # Specify float value to use floating point math
  IPP_STATUS_PASSED = 'In-person passed'
  IPP_STATUS_FAILED = 'In-person failed'
  IPP_INCOMPLETE_ERROR_MESSAGE = 'Customer has not been to a post office to complete IPP'
  IPP_EXPIRED_ERROR_MESSAGE = /More than (?<days>\d+) days have passed since opt-in to IPP/
  IPP_INVALID_ENROLLMENT_CODE_MESSAGE = 'Enrollment code %s does not exist'
  IPP_INVALID_APPLICANT_MESSAGE = 'Applicant %s does not exist'
  IPP_BAD_SPONSOR_ID_MESSAGE = /sponsorID \d+ is not registered as an IPP client/
  IPP_SPONSOR_ID_NOT_FOUND_MESSAGE = /Sponsor for sponsorID \d+ not found/
  SUPPORTED_ID_TYPES = [
    "State driver's license",
    "State non-driver's identification card",
  ].freeze
  SUPPORTED_SECONDARY_ID_TYPES = [
    'Visual Inspection of Name and Address on Primary ID Match',
  ].freeze

  queue_as :long_running

  include IppHelper

  def perform(_now)
    return unless job_can_run?

    @enrollment_outcomes = {
      enrollments_checked: 0,
      enrollments_errored: 0,
      enrollments_network_error: 0,
      enrollments_expired: 0,
      enrollments_failed: 0,
      enrollments_cancelled: 0,
      enrollments_in_progress: 0,
      enrollments_passed: 0,
    }

    started_at = Time.zone.now
    pending_enrollments.update(last_batch_claimed_at: started_at)
    enrollments_to_check = InPersonEnrollment.needs_usps_status_check_batch(started_at)

    analytics.idv_in_person_usps_proofing_results_job_started(
      enrollments_count: enrollments_to_check.count,
      reprocess_delay_minutes: reprocess_delay_minutes,
      job_name: self.class.name,
    )

    check_enrollments(enrollments_to_check)

    analytics.idv_in_person_usps_proofing_results_job_completed(
      **enrollment_outcomes,
      duration_seconds: (Time.zone.now - started_at).seconds.round(2),
      percent_enrollments_errored: summary_percent(:enrollments_errored),
      percent_enrollments_network_error: summary_percent(:enrollments_network_error),
      job_name: self.class.name,
    )
  end

  private

  attr_accessor :enrollment_outcomes

  DEFAULT_EMAIL_DELAY_IN_HOURS = 1
  REQUEST_DELAY_IN_SECONDS = (IdentityConfig.store
    .get_usps_proofing_results_job_request_delay_milliseconds / MILLISECONDS_PER_SECOND).freeze

  def proofer
    @proofer ||= UspsInPersonProofing::EnrollmentHelper.usps_proofer
  end

  def ipp_enabled?
    IdentityConfig.store.in_person_proofing_enabled == true
  end

  def ipp_ready_job_enabled?
    IdentityConfig.store.in_person_enrollments_ready_job_enabled == true
  end

  def job_can_run?
    ipp_enabled? && !ipp_ready_job_enabled?
  end

  def reprocess_delay_minutes
    IdentityConfig.store.get_usps_proofing_results_job_reprocess_delay_minutes
  end

  def pending_enrollments
    @pending_enrollments ||= InPersonEnrollment.needs_usps_status_check(
      ...reprocess_delay_minutes.minutes.ago,
    )
  end

  def check_enrollments(enrollments)
    last_enrollment_index = enrollments.length - 1
    enrollments.each_with_index do |enrollment, idx|
      check_enrollment(enrollment)
      # Sleep briefly after each call to USPS
      sleep REQUEST_DELAY_IN_SECONDS if idx < last_enrollment_index
    end
  end

  def check_enrollment(enrollment)
    status_check_attempted_at = Time.zone.now
    enrollment_outcomes[:enrollments_checked] += 1

    if enrollment.profile_has_encryption_error?
      cancel_enrollment_due_to_encryption_error(enrollment)
      return
    end

    response = proofer.request_proofing_results(
      enrollment,
    )
  rescue Faraday::BadRequestError => err
    # 400 status code. This is used for some status updates and some common client errors
    handle_bad_request_error(err, enrollment)
  rescue Faraday::ClientError, Faraday::ServerError, Faraday::Error => err
    # 4xx, 5xx and any other Faraday error besides a 400 status code.
    # These errors may or may not have a response body that we can pull info from.
    handle_client_or_server_error(err, enrollment)
  rescue StandardError => err
    handle_standard_error(err, enrollment)
  else
    process_enrollment_response(enrollment, response)
  ensure
    # Record the attempt to update the enrollment
    enrollment.update(status_check_attempted_at: status_check_attempted_at)
  end

  def cancel_enrollment_due_to_encryption_error(enrollment)
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: false,
      enrollment_completed: true,
      response: nil,
      reason: "Profile has a deactivation reason of #{enrollment.profile_deactivation_reason}",
    )
    cancel_enrollment(enrollment)
  end

  def cancel_enrollment(enrollment)
    enrollment_outcomes[:enrollments_cancelled] += 1
    enrollment.cancelled!
    enrollment.profile.deactivate_due_to_in_person_verification_cancelled
  end

  def passed_with_unsupported_secondary_id_type?(enrollment, response)
    return false if enrollment.enhanced_ipp?

    response['secondaryIdType'].present? &&
      SUPPORTED_SECONDARY_ID_TYPES.exclude?(response['secondaryIdType'])
  end

  def analytics(user: AnonymousUser.new)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end

  def summary_percent(outcomes_key)
    error_rate = 0
    if enrollment_outcomes[:enrollments_checked] > 0
      error_rate =
        (enrollment_outcomes[outcomes_key].fdiv(
          enrollment_outcomes[:enrollments_checked],
        ) * 100).round(2)
    end
    error_rate
  end

  def handle_bad_request_error(err, enrollment)
    response_body = err.response_body
    response_message = response_body&.[]('responseMessage')

    if response_message == IPP_INCOMPLETE_ERROR_MESSAGE
      # Customer has not been to post office for IPP
      handle_incomplete_status_update(enrollment, response_message)
    elsif response_message&.match(IPP_EXPIRED_ERROR_MESSAGE)
      # If we're blocking expirations, treat this enrollment as incomplete
      if IdentityConfig.store.in_person_stop_expiring_enrollments.blank?
        handle_expired_status_update(enrollment, err.response, response_message)
      else
        handle_incomplete_status_update(enrollment, response_message)
      end
    elsif response_message == IPP_INVALID_ENROLLMENT_CODE_MESSAGE % enrollment.enrollment_code
      handle_invalid_enrollment_code(enrollment, err.response, response_message)
    elsif response_message == IPP_INVALID_APPLICANT_MESSAGE % enrollment.unique_id
      handle_invalid_applicant_unique_id(enrollment, err.response, response_message)
    elsif response_message&.match(IPP_BAD_SPONSOR_ID_MESSAGE) ||
          response_message&.match(IPP_SPONSOR_ID_NOT_FOUND_MESSAGE)
      handle_sponsor_id_error(err, enrollment)
    else
      handle_client_or_server_error(err, enrollment)
    end
  end

  def handle_client_or_server_error(err, enrollment)
    NewRelic::Agent.notice_error(err)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_analytics_attributes(err.response_body),
      exception_class: err.class.to_s,
      exception_message: err.message,
      reason: 'Request exception',
      response_status_code: err.response_status,
      job_name: self.class.name,
    )

    if err.is_a?(Faraday::TimeoutError) || err.is_a?(Faraday::ConnectionFailed)
      enrollment_outcomes[:enrollments_network_error] += 1
    else
      enrollment_outcomes[:enrollments_errored] += 1
    end
  end

  def handle_sponsor_id_error(err, enrollment)
    NewRelic::Agent.notice_error(err)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_analytics_attributes(scrub_body(err.response_body)),
      exception_class: err.class.to_s,
      exception_message: err.message,
      reason: 'Request exception',
      response_status_code: err.response_status,
      job_name: self.class.name,
    )

    if err.is_a?(Faraday::TimeoutError) || err.is_a?(Faraday::ConnectionFailed)
      enrollment_outcomes[:enrollments_network_error] += 1
    else
      enrollment_outcomes[:enrollments_errored] += 1
    end
  end

  def handle_standard_error(err, enrollment)
    NewRelic::Agent.notice_error(err)
    response_attributes = response_analytics_attributes(nil)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_attributes,
      exception_class: err.class.to_s,
      exception_message: err.message,
      reason: 'Request exception',
      job_name: self.class.name,
    )
    enrollment_outcomes[:enrollments_errored] += 1
  end

  def handle_response_is_not_a_hash(enrollment)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      reason: 'Bad response structure',
      job_name: self.class.name,
    )
    enrollment_outcomes[:enrollments_errored] += 1
  end

  def handle_unsupported_status(enrollment, response)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_analytics_attributes(response),
      reason: 'Unsupported status',
      status: response['status'],
      job_name: self.class.name,
    )
    enrollment_outcomes[:enrollments_errored] += 1
  end

  def handle_unsupported_id_type(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_failed] += 1
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: false,
      enrollment_completed: true,
      response: response,
      reason: 'Unsupported ID type',
    )
    enrollment.update(
      status: :failed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )
    enrollment.profile.deactivate_due_to_in_person_verification_cancelled
    # send SMS and email
    send_enrollment_status_sms_notification(enrollment: enrollment)
    send_failed_email(enrollment:, visited_location_name: response['proofingPostOffice'])
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
      **email_analytics_attributes(enrollment),
      email_type: 'Failed unsupported ID type',
      job_name: self.class.name,
    )
  end

  def handle_incomplete_status_update(enrollment, response_message)
    enrollment_outcomes[:enrollments_in_progress] += 1
    analytics(user: enrollment.user)
      .idv_in_person_usps_proofing_results_job_enrollment_incomplete(
        **enrollment_analytics_attributes(enrollment, complete: false),
        response_message: response_message,
        job_name: self.class.name,
      )
    enrollment.update(status_check_completed_at: Time.zone.now)
  end

  def handle_expired_status_update(enrollment, response, response_message)
    enrollment_outcomes[:enrollments_expired] += 1
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: false,
      enrollment_completed: true,
      response: response[:body],
      reason: 'Enrollment has expired',
    )
    enrollment.update(
      status: :expired,
      status_check_completed_at: Time.zone.now,
    )
    enrollment.profile.deactivate_due_to_in_person_verification_cancelled

    if fraud_result_pending?(enrollment)
      analytics(user: enrollment.user).idv_ipp_deactivated_for_never_visiting_post_office(
        **enrollment_analytics_attributes(enrollment, complete: true),
      )
      enrollment.profile.deactivate_due_to_ipp_expiration_during_fraud_review
    end

    begin
      unless enrollment.deadline_passed_sent
        send_deadline_passed_email(enrollment: enrollment, visited_location_name: 'none')
      end
    rescue StandardError => err
      NewRelic::Agent.notice_error(err)
      analytics(user: enrollment.user)
        .idv_in_person_usps_proofing_results_job_deadline_passed_email_exception(
          enrollment_id: enrollment.id,
          exception_class: err.class.to_s,
          exception_message: err.message,
          job_name: self.class.name,
        )
    else
      analytics(user: enrollment.user)
        .idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated(
          **email_analytics_attributes(enrollment),
          enrollment_id: enrollment.id,
          job_name: self.class.name,
        )
      enrollment.update(deadline_passed_sent: true)
    end

    # check for an unexpected number of days until expiration
    match = response_message&.match(IPP_EXPIRED_ERROR_MESSAGE)
    expired_after_days = match && match[:days]
    if expired_after_days.present? &&
       expired_after_days.to_i != IdentityConfig.store.in_person_enrollment_validity_in_days
      handle_unexpected_response(
        enrollment,
        response_message,
        reason: 'Unexpected number of days before enrollment expired',
        cancel: false,
      )
    end
  end

  def handle_invalid_enrollment_code(enrollment, response, response_message)
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: false,
      enrollment_completed: false,
      response: response[:body],
      reason: 'Invalid enrollment code',
    )
    handle_unexpected_response(enrollment, response_message, reason: 'Invalid enrollment code')
  end

  def handle_invalid_applicant_unique_id(enrollment, response, response_message)
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: false,
      enrollment_completed: false,
      response: response[:body],
      reason: 'Invalid applicant unique id',
    )
    handle_unexpected_response(enrollment, response_message, reason: 'Invalid applicant unique id')
  end

  def handle_fraud_review_pending(enrollment)
    enrollment.profile.deactivate_for_fraud_review

    analytics(user: enrollment.user)
      .idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review(
        **enrollment_analytics_attributes(enrollment, complete: true),
      )
  end

  def handle_unexpected_response(enrollment, response_message, reason:, cancel: true)
    if cancel
      cancel_enrollment(enrollment)
    end
    analytics(user: enrollment.user)
      .idv_in_person_usps_proofing_results_job_unexpected_response(
        **enrollment_analytics_attributes(enrollment, complete: cancel),
        response_message: response_message,
        reason: reason,
        job_name: self.class.name,
      )
  end

  def handle_failed_status(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_failed] += 1
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: false,
      enrollment_completed: true,
      response: response,
      reason: 'Failed status',
    )

    enrollment.update(
      status: :failed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )
    enrollment.profile.deactivate_due_to_in_person_verification_cancelled
    # send SMS and email
    send_enrollment_status_sms_notification(enrollment: enrollment)
    visited_location_name = response['proofingPostOffice']
    if response['fraudSuspected']
      send_failed_fraud_email(enrollment:, visited_location_name:)
      analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
        **email_analytics_attributes(enrollment),
        email_type: 'Failed fraud suspected',
        job_name: self.class.name,
      )
    else
      send_failed_email(enrollment:, visited_location_name:)
      analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
        **email_analytics_attributes(enrollment),
        email_type: 'Failed',
        job_name: self.class.name,
      )
    end
  end

  def handle_successful_status_update(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_passed] += 1
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: true,
      enrollment_completed: true,
      response: response,
      reason: 'Successful status update',
    )
    enrollment.update(
      status: :passed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )

    unless fraud_result_pending?(enrollment)
      enrollment.profile&.activate_after_passing_in_person

      # send SMS and email
      send_enrollment_status_sms_notification(enrollment: enrollment)
      send_verified_email(enrollment:, visited_location_name: response['proofingPostOffice'])
      analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
        **email_analytics_attributes(enrollment),
        email_type: 'Success',
        job_name: self.class.name,
      )
    end
  end

  def handle_passed_with_fraud_review_pending(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_passed] += 1
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: true,
      enrollment_completed: true,
      response: response,
      reason: 'Passed with fraud pending',
    )
    enrollment.update(
      status: :passed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )

    # send email
    send_please_call_email(enrollment:, visited_location_name: response['proofingPostOffice'])
    analytics(user: enrollment.user)
      .idv_in_person_usps_proofing_results_job_please_call_email_initiated(
        **email_analytics_attributes(enrollment),
        job_name: self.class.name,
      )
  end

  def handle_unsupported_secondary_id(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_failed] += 1
    log_enrollment_updated_analytics(
      enrollment: enrollment,
      enrollment_passed: false,
      enrollment_completed: true,
      response: response,
      reason: 'Provided secondary proof of address',
    )
    enrollment.update(
      status: :failed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )
    enrollment.profile.deactivate_due_to_in_person_verification_cancelled
    # send SMS and email
    send_enrollment_status_sms_notification(enrollment: enrollment)
    send_failed_email(enrollment:, visited_location_name: response['proofingPostOffice'])
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
      **email_analytics_attributes(enrollment),
      email_type: 'Failed unsupported secondary ID',
      job_name: self.class.name,
    )
  end

  def fraud_result_pending?(enrollment)
    IdentityConfig.store.in_person_proofing_enforce_tmx &&
      enrollment.profile&.fraud_pending_reason.present?
  end

  # By-pass Primary ID check if enrollment is Enhanced IPP else check for supporting doc type
  def passed_with_primary_id_check?(enrollment, response)
    enrollment.enhanced_ipp? ||
      SUPPORTED_ID_TYPES.include?(response['primaryIdType'])
  end

  def process_enrollment_response(enrollment, response)
    unless response.is_a?(Hash)
      handle_response_is_not_a_hash(enrollment)
      return
    end

    # We want to deactivate them regardless of status, but then allow the
    # case statement below to pick up the correct flow.
    if fraud_result_pending?(enrollment)
      handle_fraud_review_pending(enrollment)
    end

    case response['status']
    when IPP_STATUS_PASSED
      if fraud_result_pending?(enrollment)
        handle_passed_with_fraud_review_pending(enrollment, response)
      elsif passed_with_unsupported_secondary_id_type?(enrollment, response)
        handle_unsupported_secondary_id(enrollment, response)
      elsif passed_with_primary_id_check?(enrollment, response)
        handle_successful_status_update(enrollment, response)
      else
        handle_unsupported_id_type(enrollment, response)
      end
    when IPP_STATUS_FAILED
      handle_failed_status(enrollment, response)
    else
      handle_unsupported_status(enrollment, response)
    end
  end

  def send_verified_email(enrollment:, visited_location_name:)
    enrollment.user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(user: enrollment.user, email_address: email_address).in_person_verified(
        enrollment: enrollment,
        visited_location_name: visited_location_name,
      ).deliver_later(**notification_delivery_params(enrollment))
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def send_deadline_passed_email(enrollment:, visited_location_name:)
    # rubocop:disable IdentityIdp/MailLaterLinter
    enrollment.user.confirmed_email_addresses.each do |email_address|
      UserMailer
        .with(user: enrollment.user, email_address: email_address)
        .in_person_deadline_passed(enrollment: enrollment,
                                   visited_location_name: visited_location_name)
        .deliver_later
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def send_failed_email(enrollment:, visited_location_name:)
    enrollment.user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(user: enrollment.user, email_address: email_address).in_person_failed(
        enrollment: enrollment,
        visited_location_name: visited_location_name,
      ).deliver_later(**notification_delivery_params(enrollment))
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def send_failed_fraud_email(enrollment:, visited_location_name:)
    enrollment.user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(user: enrollment.user, email_address: email_address).in_person_failed_fraud(
        enrollment: enrollment,
        visited_location_name: visited_location_name,
      ).deliver_later(**notification_delivery_params(enrollment))
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def send_please_call_email(enrollment:, visited_location_name:)
    enrollment.user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(user: enrollment.user, email_address: email_address).in_person_please_call(
        enrollment: enrollment,
        visited_location_name: visited_location_name,
      ).deliver_later(**notification_delivery_params(enrollment))
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  # enqueue sms notification job when it's expired or success
  # @param [InPersonEnrollment] enrollment
  def send_enrollment_status_sms_notification(enrollment:)
    if IdentityConfig.store.in_person_send_proofing_notifications_enabled
      InPerson::SendProofingNotificationJob.set(
        **notification_delivery_params(enrollment),
      ).perform_later(enrollment.id)
    end
  end

  def notification_delivery_params(enrollment)
    return {} unless enrollment.passed? || enrollment.failed?

    wait_until = enrollment.status_check_completed_at + (
      IdentityConfig.store.in_person_results_delay_in_hours || DEFAULT_EMAIL_DELAY_IN_HOURS
    ).hours
    return {} unless Time.zone.now < wait_until

    {
      wait_until:,
      queue: :intentionally_delayed,
    }
  end

  def email_analytics_attributes(enrollment)
    {
      enrollment_code: enrollment.enrollment_code,
      timestamp: Time.zone.now,
      service_provider: enrollment.issuer,
      wait_until: notification_delivery_params(enrollment)[:wait_until],
    }
  end

  def enrollment_analytics_attributes(enrollment, complete:)
    {
      enrollment_code: enrollment.enrollment_code,
      enrollment_id: enrollment.id,
      minutes_since_last_status_check: enrollment.minutes_since_last_status_check,
      minutes_since_last_status_check_completed:
        enrollment.minutes_since_last_status_check_completed,
      minutes_since_last_status_update: enrollment.minutes_since_last_status_update,
      minutes_since_established: enrollment.minutes_since_established,
      minutes_to_completion: complete ? enrollment.minutes_since_established : nil,
      issuer: enrollment.issuer,
    }
  end

  def response_analytics_attributes(response)
    return { response_present: false } unless response.present?

    {
      fraud_suspected: response['fraudSuspected'],
      primary_id_type: response['primaryIdType'],
      secondary_id_type: response['secondaryIdType'],
      failure_reason: response['failureReason'],
      transaction_end_date_time: parse_usps_timestamp(response['transactionEndDateTime']),
      transaction_start_date_time: parse_usps_timestamp(response['transactionStartDateTime']),
      status: response['status'],
      assurance_level: response['assuranceLevel'],
      proofing_post_office: response['proofingPostOffice'],
      proofing_city: response['proofingCity'],
      proofing_state: response['proofingState'],
      scan_count: response['scanCount'],
      response_message: response['responseMessage'],
      response_present: true,
    }
  end

  def log_enrollment_updated_analytics(enrollment:, enrollment_passed:, enrollment_completed:,
                                       response:, reason:)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_updated(
      **enrollment_analytics_attributes(enrollment, complete: enrollment_completed),
      **response_analytics_attributes(response),
      passed: enrollment_passed,
      reason: reason,
      job_name: self.class.name,
      tmx_status: enrollment.profile&.tmx_status,
      profile_age_in_seconds: enrollment.profile&.profile_age_in_seconds,
      enhanced_ipp: enrollment.enhanced_ipp?,
    )
  end

  def parse_usps_timestamp(usps_timestamp)
    return unless usps_timestamp
    # Parse timestamps eg 12/17/2020 033855 => Thu, 17 Dec 2020 03:38:55 -0600
    # Note that the USPS timestamps are in Central Standard time (UTC -6:00)
    ActiveSupport::TimeZone[-6].strptime(
      usps_timestamp,
      '%m/%d/%Y %H%M%S',
    ).in_time_zone('UTC')
  end
end
