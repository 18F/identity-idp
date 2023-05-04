module InPerson

  # This job checks a queue regularly to determine whether USPS has notitied us
  # about whether an in-person enrollment is ready to have its status checked. If
  # the enrollment is ready, then this job updates a flag on the enrollment so that it
  # will be checked earlier than other enrollments.
  class InPersonEnrollmentsReadyJob < ApplicationJob
    queue_as :low

    def perform(_now)
      return true unless IdentityConfig.store.in_person_proofing_enabled

    end

    private

    def poll
      resp = client.receive_message({
        queue_url: IdentityConfig.store.in_person_enrollments_ready_job_queue_url,
        attribute_names: ["All"], # accepts All, Policy, VisibilityTimeout, MaximumMessageSize, MessageRetentionPeriod, ApproximateNumberOfMessages, ApproximateNumberOfMessagesNotVisible, CreatedTimestamp, LastModifiedTimestamp, QueueArn, ApproximateNumberOfMessagesDelayed, DelaySeconds, ReceiveMessageWaitTimeSeconds, RedrivePolicy, FifoQueue, ContentBasedDeduplication, KmsMasterKeyId, KmsDataKeyReusePeriodSeconds, DeduplicationScope, FifoThroughputLimit, RedriveAllowPolicy, SqsManagedSseEnabled
        max_number_of_messages: IdentityConfig.store.in_person_enrollments_ready_queue_url,
        visibility_timeout: IdentityConfig.store.in_person_enrollments_ready_job_visibility_timeout,
        wait_time_seconds: IdentityConfig.store.in_person_enrollments_ready_job_wait_time_seconds,
      })
    end

    def analytics(user: AnonymousUser.new)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end

    def client
      @sqs_client ||= Aws::SQS::Client.new
    end
  end
end