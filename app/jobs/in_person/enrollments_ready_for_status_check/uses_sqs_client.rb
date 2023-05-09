module InPerson::EnrollmentsReadyForStatusCheck
  module UsesSqsClient
    def sqs_client
      @sqs_client ||= Aws::SQS::Client.new
    end

    def queue_url
      IdentityConfig.store.in_person_enrollments_ready_job_queue_url
    end
  end
end
