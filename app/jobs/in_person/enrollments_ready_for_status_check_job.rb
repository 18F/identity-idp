module InPerson
  # This job checks a queue regularly to determine whether USPS has notitied us
  # about whether an in-person enrollment is ready to have its status checked. If
  # the enrollment is ready, then this job updates a flag on the enrollment so that it
  # will be checked earlier than other enrollments.
  class EnrollmentsReadyForStatusCheckJob < ApplicationJob
    include InPerson::EnrollmentsReadyForStatusCheck::UsesAnalytics
    include InPerson::EnrollmentsReadyForStatusCheck::UsesSqsClient
    include InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor

    queue_as :low

    def perform(_now)
      return true unless IdentityConfig.store.in_person_proofing_enabled &&
                         IdentityConfig.store.in_person_enrollments_ready_job_enabled

      begin
        analytics.idv_in_person_proofing_enrollments_ready_for_status_check_job_started

        analytics_stats = {
          # total number of items fetched
          fetched_items: 0,
          # total number of items fetched and processed
          processed_items: 0,
          # total number of items fetched, processed, and then deleted from the queue
          deleted_items: 0,
          # number of items that could be successfully used to update a record
          valid_items: 0,
          # number of items that couldn't be used to update a record
          invalid_items: 0,
        }

        # Continually request messages until no messages are received
        while (messages = poll).any?
          process_batch(messages, analytics_stats)
        end
        return true
      ensure
        analytics.idv_in_person_proofing_enrollments_ready_for_status_check_job_completed(
          **analytics_stats,
          # number of fetched items that were not processed nor deleted from the queue
          incomplete_items:
            analytics_stats[:fetched_items] - analytics_stats[:processed_items],
          # number of processed items that we failed to delete
          deletion_failed_items:
            analytics_stats[:processed_items] - analytics_stats[:deleted_items],
        )
      end
    end
  end
end
