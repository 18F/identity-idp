module InPerson
  # This job checks a queue regularly to determine whether USPS has notitied us
  # about whether an in-person enrollment is ready to have its status checked. If
  # the enrollment is ready, then this job updates a flag on the enrollment so that it
  # will be checked earlier than other enrollments.
  class InPersonEnrollmentsReadyJob < ApplicationJob
    queue_as :low

    def perform(_now)
      return true unless IdentityConfig.store.in_person_proofing_enabled

      delete_messages = []
      while (messages = poll).any?
        messages.each do |sqs_message|
          begin
            sns_message = JSON.parse(sqs_message.body)
            ses_message = JSON.parse(sns_message['Message'])
          rescue JSON::JSONError
            # Delete message from queue because this is not recoverable
            delete_messages.append(sqs_message.message_id)
            next
          end

          begin
            mail = Mail.read_from_string(ses_message['content'])
            mail_body = mail.text_part&.decoded
          rescue StandardError
            # Delete message from queue because this is not recoverable
            delete_messages.append(sqs_message.message_id)
            next
          end

          unless mail_body.is_a?(String) && EMAIL_BODY_PATTERN.match?(mail_body)
            # Delete message from queue because this is not recoverable
            delete_messages.append(sqs_message.message_id)
            next
          end

          enrollment_code = text_body.strip.split(': ')[1]
          begin
            InPersonEnrollment.where(enrollment_code:).update(ready_for_status_check: true)
            delete_messages.append(sqs_message.message_id)
          rescue ActiveRecord::ActiveRecordError
            # Leave message in queue because the issue may be temporary
          end
        end
      end
    end

    private

    EMAIL_BODY_PATTERN = /\A\s*Status updated for enrollment: \d{16}\s*\Z/

    def poll
      sqs_client.receive_message(receive_params).messages
    end

    def analytics(user: AnonymousUser.new)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end

    def sqs_client
      @sqs_client ||= Aws::SQS::Client.new
    end

    def receive_params
      {
        queue_url: IdentityConfig.store.in_person_enrollments_ready_job_queue_url,
        max_number_of_messages: IdentityConfig.store.in_person_enrollments_ready_queue_url,
        visibility_timeout: IdentityConfig.store.in_person_enrollments_ready_job_visibility_timeout,
        wait_time_seconds: IdentityConfig.store.in_person_enrollments_ready_job_wait_time_seconds,
      }
    end
  end
end
