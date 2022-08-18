class GetUspsProofingResultsJob < ApplicationJob
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

  def perform(_now)
    return true unless IdentityConfig.store.in_person_proofing_enabled

    proofer = UspsInPersonProofing::Proofer.new

    reprocess_delay_minutes = IdentityConfig.store.
                              get_usps_proofing_results_job_reprocess_delay_minutes
    InPersonEnrollment.needs_usps_status_check(
      ...reprocess_delay_minutes.minutes.ago,
    ).each do |enrollment|
      # Record and commit attempt to check enrollment status to database
      enrollment.update(status_check_attempted_at: Time.zone.now)

      enrollment.update(unique_id: enrollment.usps_unique_id) if enrollment.unique_id.blank?
      response = nil

      begin
        response = proofer.request_proofing_results(
          enrollment.unique_id, enrollment.enrollment_code
        )
      rescue Faraday::BadRequestError => err
        handle_bad_request_error(err, enrollment)
        next
      rescue StandardError => err
        handle_standard_error(err, enrollment)
        next
      end

      unless response.is_a?(Hash)
        handle_response_is_not_a_hash(enrollment)
        next
      end

      update_enrollment_status(enrollment, response)
    end

    true
  end

  private

  DEFAULT_EMAIL_DELAY_IN_HOURS = 1

  def analytics(user: AnonymousUser.new)
    Analytics.new(user: user, request: nil, session: {}, sp: nil)
  end

  def handle_bad_request_error(err, enrollment)
    case err.response&.[](:body)&.[]('responseMessage')
    when IPP_INCOMPLETE_ERROR_MESSAGE
      # Customer has not been to post office for IPP
    when IPP_EXPIRED_ERROR_MESSAGE
      # Customer's IPP enrollment has expired
      enrollment.update(status: :expired)
    else
      analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
        reason: 'Request exception',
        enrollment_id: enrollment.id,
        enrollment_code: enrollment.enrollment_code,
        exception_class: err.class.to_s,
        exception_message: err.message,
      )
    end
  end

  def handle_standard_error(err, enrollment)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      reason: 'Request exception',
      enrollment_id: enrollment.id,
      enrollment_code: enrollment.enrollment_code,
      exception_class: err.class.to_s,
      exception_message: err.message,
    )
  end

  def handle_response_is_not_a_hash(enrollment)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_exception(
      reason: 'Bad response structure',
      enrollment_id: enrollment.id,
      enrollment_code: enrollment.enrollment_code,
    )
  end

  def handle_unsupported_status(enrollment, status)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_failure(
      reason: 'Unsupported status',
      enrollment_id: enrollment.id,
      enrollment_code: enrollment.enrollment_code,
      status: status,
    )
  end

  def handle_unsupported_id_type(enrollment, primary_id_type)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_failure(
      reason: 'Unsupported ID type',
      enrollment_id: enrollment.id,
      enrollment_code: enrollment.enrollment_code,
      primary_id_type: primary_id_type,
    )
  end

  def handle_failed_status(enrollment, response)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_failure(
      reason: 'Failed status',
      enrollment_id: enrollment.id,
      enrollment_code: enrollment.enrollment_code,
      failure_reason: response['failureReason'],
      fraud_suspected: response['fraudSuspected'],
      primary_id_type: response['primaryIdType'],
      proofing_state: response['proofingState'],
      secondary_id_type: response['secondaryIdType'],
      transaction_end_date_time: response['transactionEndDateTime'],
      transaction_start_date_time: response['transactionStartDateTime'],
    )
  end

  def handle_successful_status_update(enrollment)
    analytics(user: enrollment.user).idv_in_person_usps_proofing_results_job_enrollment_success(
      reason: 'Successful status update',
      enrollment_id: enrollment.id,
      enrollment_code: enrollment.enrollment_code,
    )
  end

  def update_enrollment_status(enrollment, response)
    case response['status']
    when IPP_STATUS_PASSED
      if SUPPORTED_ID_TYPES.include?(response['primaryIdType'])
        enrollment.profile.activate
        enrollment.update(status: :passed)
        handle_successful_status_update(enrollment)
        send_verified_email(enrollment.user, enrollment)
      else
        # Unsupported ID type
        enrollment.update(status: :failed)
        handle_unsupported_id_type(enrollment, response['primaryIdType'])
      end
    when IPP_STATUS_FAILED
      enrollment.update(status: :failed)
      handle_failed_status(enrollment, response)
      send_failed_email(enrollment.user, enrollment)
    else
      handle_unsupported_status(enrollment, response['status'])
    end
  end

  def send_verified_email(user, enrollment)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.in_person_verified(
        user,
        email_address,
        enrollment: enrollment,
      ).deliver_now_or_later(**mail_delivery_params)
    end
  end

  def send_failed_email(user, enrollment)
    user.confirmed_email_addresses.each do |email_address|
      UserMailer.in_person_failed(
        user,
        email_address,
        enrollment: enrollment,
      ).deliver_now_or_later(**mail_delivery_params)
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
