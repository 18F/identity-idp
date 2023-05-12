module InPerson::EnrollmentsReadyForStatusCheck
  module EnrollmentPipeline
    include UsesReportError

    # Process a message from USPS indicating that an in-person
    # enrollment is ready to have its status checked.
    #
    # When a message can't be processed, then this function will return
    # false to indicate that a problem occurred with the message. Otherwise it
    # will return true. If an error occurs that can't be clearly identified
    # as a problem with the message, then an error will be raised instead.
    #
    # When a message is successfully processed, then the corresponding
    # InPersonEnrollment record will be marked as ready for a status check.
    #
    # @param [Aws::SQS::Types::Message] sqs_message
    # @return [Boolean] Returns false for messages that can't be processed
    # @raise [StandardError] Raised when an unhandled error occurs
    def process_message(sqs_message)
      error_extra = {
        sqs_message_id: sqs_message.message_id,
      }

      # Unwrap SQS message to get SNS message
      begin
        sns_message = JSON.parse(sqs_message.body, { symbolize_names: true })
      rescue JSON::JSONError => err
        report_error(err, **error_extra)
        return false
      end

      unless sns_message.is_a?(Hash) && sns_message.key?(:MessageId) && sns_message.key?(:Message)
        report_error('SQS message body is not valid SNS payload', **error_extra)
        return false
      end

      error_extra[:sns_message_id] = sns_message[:MessageId]

      # Unwrap SNS message to get SES message
      begin
        ses_message = JSON.parse(sns_message[:Message], { symbolize_names: true })
      rescue JSON::JSONError => err
        report_error(err, **error_extra)
        return false
      end

      unless ses_message.is_a?(Hash) && ses_message.key?(:content) && ses_message.key?(:mail)
        report_error('SNS "Message" field is not a valid SES payload', **error_extra)
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

      # Parse email from content of SES message
      begin
        mail = Mail.read_from_string(ses_message[:content])
        # Depending on how the email is created, we may need to read different
        # parts of the message
        if mail.multipart?
          text_body = mail.text_part&.decoded
        else
          text_body = mail.decoded
        end
      rescue StandardError
        report_error(err, **error_extra)
        return false
      end

      unless text_body.is_a?(String)
        report_error('Email body is not a string', **error_extra)
        return false
      end

      # Extract enrollment code from email body
      enrollment_code = email_body_pattern.match(text_body)&.[](:enrollment_code)
      error_extra[:enrollment_code] = enrollment_code

      unless enrollment_code.is_a?(String)
        report_error(
          'Failed to extract enrollment code using regex, check email body format and regex',
          **error_extra,
        )
        return false
      end

      # Look up existing enrollment
      id, ready_for_status_check = InPersonEnrollment.
        where(enrollment_code:, status: :pending).
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

      error_extra[:enrollment_id] = id

      # SQS can deliver the message multiple times, so it's expected that
      # sometimes ready_for_status_check will already be set to true.
      unless ready_for_status_check
        # Mark enrollment as ready for the USPS status check
        InPersonEnrollment.update(id, ready_for_status_check: true)
      end
      return true
    rescue StandardError => err
      # Report and re-throw unhandled errors
      report_error(err, **error_extra)
      raise err
    end

    private

    # Regex pattern describing the expected email format.
    # This should include an "enrollment_code" capture group.
    def email_body_pattern
      @email_body_pattern ||= Regexp.new(
        IdentityConfig.store.in_person_enrollments_ready_job_email_body_pattern,
      )
    end
  end
end
