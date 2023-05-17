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
          fetched_items: 0,
          processed_items: 0,
          deleted_items: 0,
          valid_items: 0,
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
          incomplete_items:
            analytics_stats[:fetched_items] - analytics_stats[:processed_items],
          deletion_failed_items:
            analytics_stats[:processed_items] - analytics_stats[:deleted_items],
        )
      end
    end
  end
end
