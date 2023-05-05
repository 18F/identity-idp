module InPerson
  # This job checks a queue regularly to determine whether USPS has notitied us
  # about whether an in-person enrollment is ready to have its status checked. If
  # the enrollment is ready, then this job updates a flag on the enrollment so that it
  # will be checked earlier than other enrollments.
  class MarkInPersonEnrollmentsReadyForStatusCheckJob < ApplicationJob
    queue_as :low

    def perform(_now)
      return true unless IdentityConfig.store.in_person_proofing_enabled

      analytics.idv_mark_in_person_proofing_enrollments_ready_for_status_check_job_started

      # Continually request messages until no messages are received
      while (messages = poll).any?
        process_batch(messages)
      end

    ensure
      analytics.idv_mark_in_person_proofing_enrollments_ready_for_status_check_job_completed
    end

    private

    EMAIL_BODY_PATTERN = /\A\s*Status updated for enrollment: \d{16}\s*\Z/

    def process_message(sqs_message)
      begin
        sns_message = JSON.parse(sqs_message.body)
      rescue JSON::JSONError => err
        report_error(err)
        return
      end

      unless sns_message.is_a?(Hash)
        err = StandardError.new("#{class.name}: SQS message body is not a hash")
        report_error(err)
        return
      end

      begin
        ses_message = JSON.parse(sns_message['Message'])
      rescue JSON::JSONError => err
        report_error(err)
        return
      end

      unless ses_message.is_a?(Hash)
        err = StandardError.new("#{class.name}: SNS/SES \"Message\" field is not a hash")
        report_error(err)
        return
      end

      begin
        mail = Mail.read_from_string(ses_message['content'])
        mail_body = mail.text_part&.decoded
      rescue StandardError
        report_error(err)
        return
      end

      unless mail_body.is_a?(String) && EMAIL_BODY_PATTERN.match?(mail_body)
        err = StandardError.new("#{class.name}: Email body is not a string matching the expected pattern")
        report_error(err)
        return
      end

      enrollment_code = text_body.strip.split(': ')[1]

      id, ready_for_status_check = InPersonEnrollment.where(enrollment_code:).order(created_at: :desc).limit(1).pick(:id, :ready_for_status_check)

      if id.nil?
        err = StandardError.new("#{class.name}: Received code for enrollment that does not exist in the database")
        report_error(err)
        return
      end

      # SQS can deliver the message multiple times, so it's expected that
      # sometimes ready_for_status_check will already be set to true.
      InPersonEnrollment.update(id, ready_for_status_check: true) unless ready_for_status_check
    end

    def process_batch(messages)
      # Keep messages to delete in an array for a batch call
      deletion_batch = []
      messages.each do |sqs_message|
        process_message(sqs_message)

        # Append messages to batch so we can dequeue any that we've processed.
        #
        # If we fail to process the message now but could process it later, then
        # we should exclude that message from the deletion batch.
        deletion_batch.append({
          id: sqs_message.message_id,
          receipt_handle: sqs_message.receipt_handle,
        })
      end

    ensure
      begin
        # The messages were processed, so remove them from the queue
        sqs_client.delete_message_batch({
          queue_url:,
          entries: deletion_batch,
        })
      rescue StandardError => err
        report_error(err)
      end
    end

    def poll
      sqs_client.receive_message(receive_params).messages
    end

    def report_error(err)
      NewRelic::Agent.notice_error(err)
    end

    def analytics(user: AnonymousUser.new)
      Analytics.new(user: user, request: nil, session: {}, sp: nil)
    end

    def sqs_client
      @sqs_client ||= Aws::SQS::Client.new
    end

    def queue_url
      IdentityConfig.store.in_person_enrollments_ready_job_queue_url
    end

    def receive_params
      {
        queue_url:,
        max_number_of_messages: IdentityConfig.store.in_person_enrollments_ready_queue_url,
        visibility_timeout: IdentityConfig.store.in_person_enrollments_ready_job_visibility_timeout,
        wait_time_seconds: IdentityConfig.store.in_person_enrollments_ready_job_wait_time_seconds,
      }
    end
  end
end
