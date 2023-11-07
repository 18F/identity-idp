module InPerson
  # This job checks a queue regularly to determine whether USPS has notitied us
  # about whether an in-person enrollment is ready to have its status checked. If
  # the enrollment is ready, then this job updates a flag on the enrollment so that it
  # will be checked earlier than other enrollments.
  class EnrollmentsReadyForStatusCheckJob < ApplicationJob
    queue_as :low

    def perform(_now)
      return true if IdentityConfig.store.in_person_proofing_enabled.blank? ||
                     IdentityConfig.store.in_person_enrollments_ready_job_enabled.blank?

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

    private

    delegate :poll, to: :sqs_batch_wrapper
    delegate :process_batch, to: :batch_processor
    delegate :analytics, to: :analytics_factory

    def batch_processor
      @batch_processor ||= begin
        InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor.new(
          error_reporter: InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter.new(
            InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor.name,
            analytics,
          ),
          sqs_batch_wrapper:,
          enrollment_pipeline: InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline.new(
            error_reporter: InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter.new(
              InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline.name,
              analytics,
            ),
            email_body_pattern: Regexp.new(
              # Regex pattern describing the expected email format.
              # This should include an "enrollment_code" capture group.
              IdentityConfig.store.in_person_enrollments_ready_job_email_body_pattern,
            ),
          ),
        )
      end
    end

    def sqs_batch_wrapper
      @sqs_batch_wrapper ||= begin
        config = IdentityConfig.store
        queue_url = config.in_person_enrollments_ready_job_queue_url
        max_number_of_messages = config.in_person_enrollments_ready_job_max_number_of_messages
        visibility_timeout = config.in_person_enrollments_ready_job_visibility_timeout_seconds
        wait_time_seconds = config.in_person_enrollments_ready_job_wait_time_seconds

        # The queue will need to remain connected for at least the duration set
        # by wait_time_seconds, which may conflict with aws_http_timeout.
        #
        # Adding the two together here to create a buffer.
        http_read_timeout = config.aws_http_timeout + wait_time_seconds

        InPerson::EnrollmentsReadyForStatusCheck::SqsBatchWrapper.new(
          sqs_client: Aws::SQS::Client.new(
            http_read_timeout:,
          ),
          queue_url:,
          receive_params: {
            queue_url:,
            max_number_of_messages:,
            visibility_timeout:,
            wait_time_seconds:,
          },
        )
      end
    end

    def analytics
      @analytics ||= Analytics.new(
        user: AnonymousUser.new,
        request: nil,
        session: {},
        sp: nil,
      )
    end
  end
end
