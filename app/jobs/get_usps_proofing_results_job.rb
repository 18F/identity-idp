class GetUspsProofingResultsJob < ApplicationJob
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

    true
  end
end