class GetUspsProofingResultsJob < ApplicationJob
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
    InPersonEnrollment.needs_usps_status_check.each do |enrollment|
      # Record and commit attempt to check enrollment status to database
      enrollment.status_check_attempted_at = Time.now
      enrollment.save

      # todo replace with feature flag check
      if false
        # todo does this need to be factoried?
        proofer = UspsInPersonProofer.new

        # todo determine stable unique ID for user (or profile?)
        unique_id = SecureRandom.hex(4)

        response = proofer.request_proofing_results unique_id, enrollment.enrollment_code
        unless response.is_a? Hash
          # todo log error
          next
        end

        # Customer has not been to post office for IPP
        if response['status'] == nil
          next
        end

        # Unsupported ID type
        if SUPPORTED_ID_TYPES.includes? response['primaryIdType']
          # todo retroactively fail enrollment
          next
        end
      end
    end
    true
  end
end