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

    proofer = UspsInPersonProofer.new

    InPersonEnrollment.needs_usps_status_check(...5.minutes.ago).each do |enrollment|
      # Record and commit attempt to check enrollment status to database
      enrollment.update(status_check_attempted_at: Time.zone.now)
      unique_id = enrollment.usps_unique_id
      response = nil

      begin
        response = proofer.request_proofing_results(unique_id, enrollment.enrollment_code)
      rescue Faraday::BadRequestError => err
        handle_bad_request_error(err, enrollment)
        next
      rescue StandardError => err
        handle_standard_error(err, enrollment)
        next
      end

      unless response.is_a?(Hash)
        handle_response_is_a_hash(enrollment)
        next
      end

      update_enrollment_status(enrollment, response['status'], response['primaryIdType'])
    end

    true
  end

  private

  def handle_bad_request_error(err, enrollment)
    case err.response&.[](:body)&.[]('responseMessage')
    when IPP_INCOMPLETE_ERROR_MESSAGE
      # Customer has not been to post office for IPP
    when IPP_EXPIRED_ERROR_MESSAGE
      # Customer's IPP enrollment has expired
      enrollment.update(status: :expired)
    else
      IdentityJobLogSubscriber.logger.warn(
        {
          name: 'get_usps_proofing_results_job.errors.request_exception',
          enrollment_id: enrollment.id,
          exception: {
            class: err.class.to_s,
            message: err.message,
            backtrace: err.backtrace,
          },
        }.to_json,
      )
    end
  end

  def handle_standard_error(err, enrollment)
    IdentityJobLogSubscriber.logger.error(
      {
        name: 'get_usps_proofing_results_job.errors.request_exception',
        enrollment_id: enrollment.id,
        exception: {
          class: err.class.to_s,
          message: err.message,
          backtrace: err.backtrace,
        },
      }.to_json,
    )
  end

  def handle_response_is_a_hash(enrollment)
    IdentityJobLogSubscriber.logger.error(
      {
        name: 'get_usps_proofing_results_job.errors.bad_response_structure',
        enrollment_id: enrollment.id,
      }.to_json,
    )
  end

  def handle_unsupported_status(enrollment, status)
    IdentityJobLogSubscriber.logger.error(
      {
        name: 'get_usps_proofing_results_job.errors.unsupported_status',
        enrollment_id: enrollment.id,
        status: status,
      }.to_json,
    )
  end

  def update_enrollment_status(enrollment, status, primary_id_type)
    case status
    when IPP_STATUS_PASSED
      if SUPPORTED_ID_TYPES.include?(primary_id_type)
        enrollment.update(status: :passed)
      else
        # Unsupported ID type
        enrollment.update(status: :failed)
      end
    when IPP_STATUS_FAILED
      enrollment.update(status: :failed)
    else
      handle_unsupported_status(enrollment, status)
    end
  end
end
