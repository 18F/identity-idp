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
    return true unless IdentityConfig.store.in_person_proofing_enabled

    proofer = UspsInPersonProofer.new

    InPersonEnrollment.needs_usps_status_check(...5.minutes.ago).each do |enrollment|
      # todo determine stable unique ID for user (or profile?)
      unique_id = enrollment.usps_enrollment_id

      # Record and commit attempt to check enrollment status to database
      enrollment.status_check_attempted_at = Time.now
      enrollment.save

      # todo dev is likely configured w/ the appropriate env but check again later
      # todo reconfigure this to call the actual endpoint
      # if false
        response = proofer.request_proofing_results unique_id, enrollment.enrollment_code
      # else
        # pass
        # response = JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_passed_proofing_results_response.json")
        # fail
        # response = JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_failed_proofing_results_response.json")
        # progress
        # response = JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_in_progress_proofing_results_response.json")
        # invalid
        response = "fubar"
      # end

      unless response.is_a? Hash
        # todo log error (treat like 500)
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
    true
  end
end