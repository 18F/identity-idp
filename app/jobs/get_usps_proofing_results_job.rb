class GetUspsProofingResultsJob < ApplicationJob
  MILLISECONDS_PER_SECOND = 1000.0 # Specify float value to use floating point math
  IPP_STATUS_PASSED = 'In-person passed'
  IPP_STATUS_FAILED = 'In-person failed'
  IPP_INCOMPLETE_ERROR_MESSAGE = 'Customer has not been to a post office to complete IPP'
  IPP_EXPIRED_ERROR_MESSAGE = 'More than 30 days have passed since opt-in to IPP'
  SUPPORTED_ID_TYPES = [
    "State driver's license",
    "State non-driver's identification card",
  ]

  queue_as :default
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: 'get_usps_proofing_results',
  )

  discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

  def email_analytics_attributes(enrollment)
    {
      timestamp: Time.zone.now,
      user_id: enrollment.user_id,
      service_provider: enrollment.issuer,
      delay_time_seconds: mail_delivery_params[:wait],
    }
  end

  def enrollment_analytics_attributes(enrollment, complete:)
    {
      enrollment_code: enrollment.enrollment_code,
      enrollment_id: enrollment.id,
      minutes_since_last_status_check: enrollment.minutes_since_last_status_check,
      minutes_since_last_status_update: enrollment.minutes_since_last_status_update,
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
      transaction_end_date_time: response['transactionEndDateTime'],
      transaction_start_date_time: response['transactionStartDateTime'],
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

  def perform(_now)
    return true unless IdentityConfig.store.in_person_proofing_enabled

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
    )

    check_enrollments(enrollments)

    analytics.idv_in_person_usps_proofing_results_job_completed(
      **enrollment_outcomes,
      duration_seconds: (Time.zone.now - started_at).seconds.round(2),
    )

    true
  end

  private

  attr_accessor :enrollment_outcomes

  DEFAULT_EMAIL_DELAY_IN_HOURS = 1

  def check_enrollments(enrollments)
    request_delay_in_seconds = IdentityConfig.store.
      get_usps_proofing_results_job_request_delay_milliseconds / MILLISECONDS_PER_SECOND
    proofer = UspsInPersonProofing::Proofer.new

    enrollments.each_with_index do |enrollment, idx|
      # Add a unique ID for enrollments that don't have one
      enrollment.update(unique_id: enrollment.usps_unique_id) if enrollment.unique_id.blank?

      status_check_attempted_at = Time.zone.now
      enrollment_outcomes[:enrollments_checked] += 1
      response = nil
      errored = true

      begin
        response = proofer.request_proofing_results(
          enrollment.unique_id, enrollment.enrollment_code
        )
        errored = false
      rescue Faraday::BadRequestError => err
        handle_bad_request_error(err, enrollment)
      rescue StandardError => err
        NewRelic::Agent.notice_error(err)
        handle_standard_error(err, enrollment)
      end

      process_enrollment_response(enrollment, response) unless errored

      # Record the attempt to update the enrollment
      enrollment.update(status_check_attempted_at: status_check_attempted_at)

      # Sleep for a while before we attempt to make another call to USPS
      sleep request_delay_in_seconds if idx < enrollments.length - 1
    end
  end

  def analytics(user: AnonymousUser.new)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end

  def handle_bad_request_error(err, enrollment)
    case err.response&.[](:body)&.[]('responseMessage')
    when IPP_INCOMPLETE_ERROR_MESSAGE
      # Customer has not been to post office for IPP
      enrollment_outcomes[:enrollments_in_progress] += 1
    when IPP_EXPIRED_ERROR_MESSAGE
      handle_expired_status_update(enrollment, err.response)
    else
      analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
        **enrollment_analytics_attributes(enrollment, complete: false),
        **response_analytics_attributes(err.response&.[](:body)),
        reason: 'Request exception',
        exception_class: err.class.to_s,
        exception_message: err.message,
      )
      enrollment_outcomes[:enrollments_errored] += 1
    end
  end

  def handle_standard_error(err, enrollment)
    response_attributes = if err.respond_to?(:response)
                            response_analytics_attributes(err.response)
                          else
                            response_analytics_attributes(nil)
                          end

    enrollment_outcomes[:enrollments_errored] += 1
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_attributes,
      reason: 'Request exception',
      exception_class: err.class.to_s,
      exception_message: err.message,
    )
  end

  def handle_response_is_not_a_hash(enrollment)
    enrollment_outcomes[:enrollments_errored] += 1
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      reason: 'Bad response structure',
    )
  end

  def handle_unsupported_status(enrollment, response)
    enrollment_outcomes[:enrollments_errored] += 1
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      **enrollment_analytics_attributes(enrollment, complete: false),
      **response_analytics_attributes(response),
      reason: 'Unsupported status',
      status: response['status'],
    )
  end

  def handle_unsupported_id_type(enrollment, response)
    enrollment_outcomes[:enrollments_failed] += 1
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_updated(
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response),
      fraud_suspected: response['fraudSuspected'],
      passed: false,
      primary_id_type: response['primaryIdType'],
      reason: 'Unsupported ID type',
    )
    enrollment.update(status: :failed)
  end

  def handle_expired_status_update(enrollment, response)
    enrollment_outcomes[:enrollments_expired] += 1
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_updated(
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response[:body]),
      passed: false,
      reason: 'Enrollment has expired',
    )
    enrollment.update(status: :expired)
  end

  def handle_failed_status(enrollment, response)
    enrollment_outcomes[:enrollments_failed] += 1
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_updated(
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(response),
      passed: false,
      reason: 'Failed status',
    )

    enrollment.update(status: :failed)
    if response['fraudSuspected']
      send_failed_fraud_email(enrollment.user, enrollment)
      analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
        **email_analytics_attributes(enrollment),
        email_type: 'Failed fraud suspected',
      )
    else
      send_failed_email(enrollment.user, enrollment)
      analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
        **email_analytics_attributes(enrollment),
        email_type: 'Failed',
      )
    end
  end

  def handle_successful_status_update(enrollment, response)
    enrollment_outcomes[:enrollments_passed] += 1
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_updated(
      **enrollment_analytics_attributes(enrollment, complete: true),
      **response_analytics_attributes(**response),
      fraud_suspected: response['fraudSuspected'],
      passed: true,
      reason: 'Successful status update',
    )
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_email_initiated(
      **email_analytics_attributes(enrollment),
      email_type: 'Success',
    )
    enrollment.profile.activate
    enrollment.update(status: :passed)
    send_verified_email(enrollment.user, enrollment)
  end

  def process_enrollment_response(enrollment, response)
    unless response.is_a?(Hash)
      handle_response_is_not_a_hash(enrollment)
      return
    end

    case response['status']
    when IPP_STATUS_PASSED
      if SUPPORTED_ID_TYPES.include?(response['primaryIdType'])
        handle_successful_status_update(enrollment, response)
      else
        # Unsupported ID type
        handle_unsupported_id_type(enrollment, response)
      end
    when IPP_STATUS_FAILED
      handle_failed_status(enrollment, response)
    else
      handle_unsupported_status(enrollment, response)
    end
  end

  def send_verified_email(user, enrollment)
    user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(user: user, email_address: email_address).in_person_verified(
        enrollment: enrollment,
      ).deliver_later(**mail_delivery_params)
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def send_failed_email(user, enrollment)
    user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(user: user, email_address: email_address).in_person_failed(
        enrollment: enrollment,
      ).deliver_later(**mail_delivery_params)
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def send_failed_fraud_email(user, enrollment)
    user.confirmed_email_addresses.each do |email_address|
      # rubocop:disable IdentityIdp/MailLaterLinter
      UserMailer.with(user: user, email_address: email_address).in_person_failed_fraud(
        enrollment: enrollment,
      ).deliver_later(**mail_delivery_params)
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end

  def mail_delivery_params
    config_delay = IdentityConfig.store.in_person_results_delay_in_hours
    if config_delay > 0
      return { wait: config_delay.hours }
    elsif (config_delay == 0)
      return {}
    end
    { wait: DEFAULT_EMAIL_DELAY_IN_HOURS.hours }
  end
end
