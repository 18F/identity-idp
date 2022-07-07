class GetUspsProofingResultsJob < ApplicationJob
  IPP_STATUS_PASSED = "In-person passed"
  IPP_STATUS_FAILED = "In-person failed"
  IPP_INCOMPLETE_ERROR_MESSAGE = "Customer has not been to a post office to complete IPP"
  IPP_EXPIRED_ERROR_MESSAGE = "More than 30 days have passed since opt-in to IPP"
  SUPPORTED_ID_TYPES = [
    "State driver's license",
    "State non-driver's identification card",
  ]

  queue_as :default
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> do
        "get_usps_proofing_results"
    end,
  )

  discard_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError

  def perform(_now)
    return true unless IdentityConfig.store.in_person_proofing_enabled

    proofer = UspsInPersonProofer.new

    InPersonEnrollment.needs_usps_status_check(...5.minutes.ago).each do |enrollment|
      # todo determine stable unique ID for user (or profile?)
      unique_id = enrollment.usps_enrollment_id

      # Record and commit attempt to check enrollment status to database
      enrollment.status_check_attempted_at = Time.now
      enrollment.save

      response = nil
      begin
        response = proofer.request_proofing_results unique_id, enrollment.enrollment_code
      rescue Faraday::BadRequestError => err
        case err.response[:body]&.[]('responseMessage')
        when IPP_INCOMPLETE_ERROR_MESSAGE
          # Customer has not been to post office for IPP
          next
        when IPP_EXPIRED_ERROR_MESSAGE
          # Customer's IPP enrollment has expired
          enrollment.status = :expired
          enrollment.save
          next
        else
          IdentityJobLogSubscriber.logger.error(
            {
              name: 'get_usps_proofing_results_job.errors.request_exception',
              enrollment_id: enrollment.id,
              exception: {
                class: err.class,
                message: err.message,
                backtrace: err.backtrace,
              },
            }.to_json,
          )
          next
        end
      rescue Exception => err
        IdentityJobLogSubscriber.logger.error(
          {
            name: 'get_usps_proofing_results_job.errors.request_exception',
            enrollment_id: enrollment.id,
            exception: {
              class: err.class,
              message: err.message,
              backtrace: err.backtrace,
            },
          }.to_json,
        )
        next
      end

      unless response.is_a? Hash
        IdentityJobLogSubscriber.logger.error(
          {
            name: 'get_usps_proofing_results_job.errors.bad_response_structure',
            enrollment_id: enrollment.id,
          }.to_json,
        )
        next
      end

      case response['status']
      when IPP_STATUS_PASSED
        if SUPPORTED_ID_TYPES.include? response['primaryIdType']
          enrollment.status = :passed
        else
          # Unsupported ID type
          enrollment.status = :failed
        end
        enrollment.save
      when IPP_STATUS_FAILED
        enrollment.status = :failed
        enrollment.save
      else
        IdentityJobLogSubscriber.logger.error(
          {
            name: 'get_usps_proofing_results_job.errors.unsupported_status',
            enrollment_id: enrollment.id,
            status: response['status'],
          }.to_json,
        )
      end
    end
    true
  end
end