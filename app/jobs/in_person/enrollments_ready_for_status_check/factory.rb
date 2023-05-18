module InPerson::EnrollmentsReadyForStatusCheck
  class Factory
    def create_batch_processor
      InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor.new(
        error_reporter: create_error_reporter(
          InPerson::EnrollmentsReadyForStatusCheck::BatchProcessor.name
        ),
        sqs_batch_wrapper: create_sqs_batch_wrapper,
        enrollment_pipeline: create_enrollment_pipeline,
      )
    end

    def create_enrollment_pipeline
      InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline.new(
        error_reporter: create_error_reporter(
          InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline.name
        ),
        email_body_pattern: Regexp.new(
          # Regex pattern describing the expected email format.
          # This should include an "enrollment_code" capture group.
          IdentityConfig.store.in_person_enrollments_ready_job_email_body_pattern,
        ),
      )
    end

    def create_sqs_batch_wrapper
      config = IdentityConfig.store
      queue_url = config.in_person_enrollments_ready_job_queue_url
      max_number_of_messages = config.in_person_enrollments_ready_job_max_number_of_messages
      visibility_timeout = config.in_person_enrollments_ready_job_visibility_timeout_seconds
      wait_time_seconds = config.in_person_enrollments_ready_job_wait_time_seconds

      self.new(
        sqs_client: Aws::SQS::Client.new,
        queue_url:,
        receive_params: {
          queue_url:,
          max_number_of_messages:,
          visibility_timeout:,
          wait_time_seconds:,
        },
      )
    end

    def create_error_reporter(class_name)
      InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter.new(
        class_name,
        create_analytics_factory,
      )
    end

    def create_analytics_factory
      InPerson::EnrollmentsReadyForStatusCheck::UserAnalyticsFactory.new
    end
  end
end