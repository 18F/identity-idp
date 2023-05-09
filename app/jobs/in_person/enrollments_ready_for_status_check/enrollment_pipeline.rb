module InPerson::EnrollmentsReadyForStatusCheck
  module EnrollmentPipeline
    include UsesReportError

    def process_message(sqs_message)
      error_extra = {
        sqs_message_id: sqs_message.message_id,
      }
      begin
        sns_message = JSON.parse(sqs_message.body, { symbolize_names: true })
      rescue JSON::JSONError => err
        report_error(err, **error_extra)
        return false
      end

      unless sns_message.is_a?(Hash)
        report_error('SQS message body is not a hash', **error_extra)
        return false
      end

      error_extra[:sns_message_id] = sns_message[:MessageId]

      begin
        ses_message = JSON.parse(sns_message[:Message], { symbolize_names: true })
      rescue JSON::JSONError => err
        report_error(err, **error_extra)
        return false
      end

      unless ses_message.is_a?(Hash)
        report_error('SNS/SES "Message" field is not a hash', **error_extra)
        return false
      end

      # Add information to help with debugging
      error_extra[:ses_aws_message_id] = ses_message.dig(:mail, :messageId)
      error_extra[:ses_mail_timestamp] = ses_message.dig(:mail, :timestamp)
      error_extra[:ses_mail_source] = ses_message.dig(:mail, :source)

      # https://datatracker.ietf.org/doc/html/rfc5322#section-3.6.1
      error_extra[:ses_rfc_origination_date] = ses_message.
        dig(:mail, :commonHeaders, :date)&.tap do |date|
          DateTime.parse(date).to_s
        end
      # https://datatracker.ietf.org/doc/html/rfc5322#section-3.6.4
      error_extra[:ses_rfc_message_id] = ses_message.dig(:mail, :commonHeaders, :messageId)

      begin
        mail = Mail.read_from_string(ses_message['content'])
        text_body = mail.text_part&.decoded
      rescue StandardError
        report_error(err, **error_extra)
        return false
      end

      unless text_body.is_a?(String)
        report_error('Email body is not a string', **error_extra)
        return false
      end

      enrollment_code = EMAIL_BODY_PATTERN.match(text_body)&.[](:enrollment_code)
      error_extra[:enrollment_code] = enrollment_code

      unless enrollment_code.is_a?(String)
        report_error(
          'Failed to extract enrollment code using regex, check email body format and regex',
          **error_extra,
        )
        return false
      end

      id, ready_for_status_check = InPersonEnrollment.
        where(enrollment_code:).
        order(created_at: :desc).
        limit(1).
        pick(
          :id, :ready_for_status_check
        )

      if id.nil?
        report_error(
          'Received code for enrollment that does not exist in the database',
          **error_extra,
        )
        return false
      end

      # SQS can deliver the message multiple times, so it's expected that
      # sometimes ready_for_status_check will already be set to true.
      InPersonEnrollment.update(id, ready_for_status_check: true) unless ready_for_status_check
      return true
    rescue StandardError => err
      report_error('Unhandled error encountered while processing enrollment', **error_extra)
      raise err
    end

    private

    EMAIL_BODY_PATTERN = IdentityConfig.store.in_person_enrollments_ready_job_email_body_pattern
  end
end
