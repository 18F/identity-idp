class GetUspsProofingResultsJob < ApplicationJob
  include JobHelpers::UspsProofingResultsJob::EmailHelper
  include JobHelpers::UspsProofingResultsJob::AnalyticsHelper

  MILLISECONDS_PER_SECOND = 1000.0 # Specify float value to use floating point math
  IPP_STATUS_PASSED = 'In-person passed'
  IPP_STATUS_FAILED = 'In-person failed'
  IPP_INCOMPLETE_ERROR_MESSAGE = 'Customer has not been to a post office to complete IPP'
  IPP_EXPIRED_ERROR_MESSAGE = /More than (?<days>\d+) days have passed since opt-in to IPP/
  IPP_INVALID_ENROLLMENT_CODE_MESSAGE = 'Enrollment code %s does not exist'
  IPP_INVALID_APPLICANT_MESSAGE = 'Applicant %s does not exist'
  SUPPORTED_ID_TYPES = [
    "State driver's license",
    "State non-driver's identification card",
  ]

  queue_as :long_running

  def perform(_now)
    return true unless ipp_enabled?

    @enrollment_outcomes = {
      enrollments_checked: 0,
      enrollments_errored: 0,
      enrollments_expired: 0,
      enrollments_failed: 0,
      enrollments_in_progress: 0,
      enrollments_passed: 0,
    }

    reprocess_delay_minutes = IdentityConfig.store.
      get_usps_proofing_results_job_reprocess_delay_minutes
    enrollments = InPersonEnrollment.needs_usps_status_check(
      ...reprocess_delay_minutes.minutes.ago,
    )

    started_at = Time.zone.now
    analytics.idv_in_person_usps_proofing_results_job_started(
      enrollments_count: enrollments.count,
      reprocess_delay_minutes: reprocess_delay_minutes,
      job_name: self.class.name,
    )

    check_enrollments(enrollments)

    analytics.idv_in_person_usps_proofing_results_job_completed(
      **enrollment_outcomes,
      duration_seconds: (Time.zone.now - started_at).seconds.round(2),
      percent_enrollments_errored: percent_errored,
      job_name: self.class.name,
    )

    true
  end

  private

  attr_accessor :enrollment_outcomes

  DEFAULT_EMAIL_DELAY_IN_HOURS = 1
  REQUEST_DELAY_IN_SECONDS = IdentityConfig.store.
    get_usps_proofing_results_job_request_delay_milliseconds / MILLISECONDS_PER_SECOND

  def proofer
    @proofer ||= UspsInPersonProofing::Proofer.new
  end

  def ipp_enabled?
    IdentityConfig.store.in_person_proofing_enabled == true
  end

  def ipp_ready_job_enabled?
    IdentityConfig.store.in_person_enrollments_ready_job_enabled == true
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
    # Add a unique ID for enrollments that don't have one
    enrollment.update(unique_id: enrollment.usps_unique_id) if enrollment.unique_id.blank?

    status_check_attempted_at = Time.zone.now
    enrollment_outcomes[:enrollments_checked] += 1
    response = nil

    response = proofer.request_proofing_results(
      enrollment.unique_id, enrollment.enrollment_code
    )
  rescue Faraday::BadRequestError => err
    # 400 status code. This is used for some status updates and some common client errors
    handle_bad_request_error(err, enrollment)
  rescue Faraday::ClientError, Faraday::ServerError, Faraday::Error => err
    # 4xx or 5xx status code.
    # These are unexpected but will have some sort of response body that we can try to log data from
    # Faraday Timeouts, failed connections, parsing errors, and other HTTP errors.
    # These generally won't have a response body
    handle_client_or_server_error(err, enrollment)
  rescue StandardError => err
    handle_standard_error(err, enrollment)
  else
    process_enrollment_response(enrollment, response)
  ensure
    # Record the attempt to update the enrollment
    enrollment.update(status_check_attempted_at: status_check_attempted_at)
  end

  def percent_errored
    error_rate = 0
    if enrollment_outcomes[:enrollments_checked] > 0
      error_rate =
        (enrollment_outcomes[:enrollments_errored].fdiv(
          enrollment_outcomes[:enrollments_checked],
        ) * 100).round(0)
    end
    error_rate
  end

  def handle_bad_request_error(err, enrollment)
    response_body = err.response_body
    response_message = response_body&.[]('responseMessage')

    if response_message == IPP_INCOMPLETE_ERROR_MESSAGE
      # Customer has not been to post office for IPP
      handle_incomplete_status_update(enrollment, response_message)
      analytics_payload = {
        **enrollment_analytics_attributes(enrollment, complete: false),
        response_message: response_message,
        job_name: self.class.name,
      }
      analytics_ipp_job_enrollment_incomplete(user: enrollment.user, payload: analytics_payload)
      enrollment.update(status_check_completed_at: Time.zone.now)
    elsif response_message&.match(IPP_EXPIRED_ERROR_MESSAGE)
      # If we're blocking expirations, treat this enrollment as incomplete
      if IdentityConfig.store.in_person_stop_expiring_enrollments.blank?
        handle_expired_status_update(enrollment, err.response, response_message)
      else
        handle_incomplete_status_update(enrollment, response_message)
      end
    elsif response_message == IPP_INVALID_ENROLLMENT_CODE_MESSAGE % enrollment.enrollment_code
      handle_unexpected_response(enrollment, response_message, reason: 'Invalid enrollment code')
    elsif response_message == IPP_INVALID_APPLICANT_MESSAGE % enrollment.unique_id
      handle_unexpected_response(
        enrollment, response_message, reason: 'Invalid applicant unique id'
      )
    else
      handle_client_or_server_error(err, enrollment)
    end
  end

  def handle_client_or_server_error(err, enrollment)
    NewRelic::Agent.notice_error(err)
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_analytics_attributes(err.response_body),
      exception_class: err.class.to_s,
      exception_message: err.message,
      reason: 'Request exception',
      response_status_code: err.response_status,
      job_name: self.class.name,
    }
    analytics_ipp_job_exception(user: enrollment.user, payload: analytics_payload)
    enrollment_outcomes[:enrollments_errored] += 1
  end

  def handle_standard_error(err, enrollment)
    NewRelic::Agent.notice_error(err)
    response_attributes = response_analytics_attributes(nil)
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_attributes,
      exception_class: err.class.to_s,
      exception_message: err.message,
      reason: 'Request exception',
      job_name: self.class.name,
    }
    analytics_ipp_job_exception(user: enrollment.user, payload: analytics_payload)
    enrollment_outcomes[:enrollments_errored] += 1
  end

  def handle_response_is_not_a_hash(enrollment)
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: false),
      reason: 'Bad response structure',
      job_name: self.class.name,
    }
    analytics_ipp_job_exception(user: enrollment.user, payload: analytics_payload)
    enrollment_outcomes[:enrollments_errored] += 1
  end

  def handle_unsupported_status(enrollment, response)
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_analytics_attributes(response),
      reason: 'Unsupported status',
      status: response['status'],
      job_name: self.class.name,
    }
    analytics_ipp_job_exception(user: enrollment.user, payload: analytics_payload)
    enrollment_outcomes[:enrollments_errored] += 1
  end

  def handle_unsupported_id_type(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_failed] += 1
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response),
      passed: false,
      primary_id_type: response['primaryIdType'],
      reason: 'Unsupported ID type',
      job_name: self.class.name,
    }
    analytics_ipp_job_enrollment_updated(user: enrollment.user, payload: analytics_payload)
    enrollment.update(
      status: :failed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )

    send_failed_email(enrollment.user, enrollment)
    email_analytics_payload = {
      **email_analytics_attributes(enrollment),
      email_type: 'Failed unsupported ID type',
      job_name: self.class.name,
    }
    analytics_ipp_job_email_initiated(user: enrollment.user, payload: email_analytics_payload)
  end

  def handle_incomplete_status_update(enrollment, response_message)
    enrollment_outcomes[:enrollments_in_progress] += 1
    analytics(user: enrollment.user).
      idv_in_person_usps_proofing_results_job_enrollment_incomplete(
        **enrollment_analytics_attributes(enrollment, complete: false),
        response_message: response_message,
        job_name: self.class.name,
      )
    enrollment.update(status_check_completed_at: Time.zone.now)
  end

  def handle_expired_status_update(enrollment, response, response_message)
    enrollment_outcomes[:enrollments_expired] += 1
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response[:body]),
      passed: false,
      reason: 'Enrollment has expired',
      job_name: self.class.name,
    }
    analytics_ipp_job_enrollment_updated(user: enrollment.user, payload: analytics_payload)
    enrollment.update(
      status: :expired,
      status_check_completed_at: Time.zone.now,
    )

    begin
      send_deadline_passed_email(enrollment.user, enrollment) unless enrollment.deadline_passed_sent
    rescue StandardError => err
      NewRelic::Agent.notice_error(err)
      analytics_payload = {
        enrollment_id: enrollment.id,
        exception_class: err.class.to_s,
        exception_message: err.message,
        job_name: self.class.name,
      }
      analytics_ipp_job_deadline_passed_email(user: enrollment.user, payload: analytics_payload)
    else
      analytics_payload = {
        **email_analytics_attributes(enrollment),
        enrollment_id: enrollment.id,
        job_name: self.class.name,
      }
      analytics_ipp_job_deadline_passed_email_initiated(
        user: enrollment.user,
        payload: analytics_payload,
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

  def handle_unexpected_response(enrollment, response_message, reason:, cancel: true)
    enrollment.cancelled! if cancel

    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: cancel),
      response_message: response_message,
      reason: reason,
      job_name: self.class.name,
    }
    analytics_ipp_job_unexpected_response(user: enrollment.user, payload: analytics_payload)
  end

  def handle_failed_status(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_failed] += 1
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response),
      passed: false,
      reason: 'Failed status',
      job_name: self.class.name,
    }
    analytics_ipp_job_enrollment_updated(user: enrollment.user, payload: analytics_payload)

    enrollment.update(
      status: :failed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )
    if response['fraudSuspected']
      send_failed_fraud_email(enrollment.user, enrollment)
      email_analytics_payload = {
        **email_analytics_attributes(enrollment),
        email_type: 'Failed fraud suspected',
        job_name: self.class.name,
      }
      analytics_ipp_job_email_initiated(user: enrollment.user, payload: email_analytics_payload)
    else
      send_failed_email(enrollment.user, enrollment)
      email_analytics_payload = {
        **email_analytics_attributes(enrollment),
        email_type: 'Failed',
        job_name: self.class.name,
      }
      analytics_ipp_job_email_initiated(user: enrollment.user, payload: email_analytics_payload)
    end
  end

  def handle_successful_status_update(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_passed] += 1
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response),
      passed: true,
      reason: 'Successful status update',
      job_name: self.class.name,
    }
    analytics_ipp_job_enrollment_updated(user: enrollment.user, payload: analytics_payload)
    enrollment.profile.activate_after_passing_in_person
    enrollment.update(
      status: :passed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )
    send_verified_email(enrollment.user, enrollment)
    email_analytics_payload = {
      **email_analytics_attributes(enrollment),
      email_type: 'Success',
      job_name: self.class.name,
    }
    analytics_ipp_job_email_initiated(user: enrollment.user, payload: email_analytics_payload)
  end

  def handle_unsupported_secondary_id(enrollment, response)
    proofed_at = parse_usps_timestamp(response['transactionEndDateTime'])
    enrollment_outcomes[:enrollments_failed] += 1
    analytics_payload = {
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response),
      passed: false,
      reason: 'Provided secondary proof of address',
      job_name: self.class.name,
    }
    analytics_ipp_job_enrollment_updated(user: enrollment.user, payload: analytics_payload)
    enrollment.update(
      status: :failed,
      proofed_at: proofed_at,
      status_check_completed_at: Time.zone.now,
    )
    send_failed_email(enrollment.user, enrollment)
    email_analytics_payload = {
      **email_analytics_attributes(enrollment),
      email_type: 'Failed unsupported secondary ID',
      job_name: self.class.name,
    }
    analytics_ipp_job_email_initiated(user: enrollment.user, payload: email_analytics_payload)
  end

  def process_enrollment_response(enrollment, response)
    unless response.is_a?(Hash)
      handle_response_is_not_a_hash(enrollment)
      return
    end

    case response['status']
    when IPP_STATUS_PASSED
      if enrollment.capture_secondary_id_enabled && response['secondaryIdType'].present?
        handle_unsupported_secondary_id(enrollment, response)
      elsif SUPPORTED_ID_TYPES.include?(response['primaryIdType'])
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
