# frozen_string_literal: true

module AnalyticsEvents
  module EmailEvents

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] user_id User the email is linked to
    # @param [Boolean] from_select_email_flow Whether email was added as part of partner email
    #   selection.
    # A user has clicked the confirmation link in an email
    def add_email_confirmation(
      user_id:,
      success:,
      from_select_email_flow:,
      error_details: nil,
      **extra
    )
      track_event(
        'Add Email: Email Confirmation',
        user_id:,
        success:,
        error_details:,
        from_select_email_flow:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] domain_name Domain name of email address submitted
    # @param [Boolean] in_select_email_flow Whether email is being added as part of partner email
    #   selection.
    # Tracks request for adding new emails to an account
    def add_email_request(
      success:,
      domain_name:,
      in_select_email_flow:,
      error_details: nil,
      **extra
    )
      track_event(
        'Add Email Requested',
        success:,
        error_details:,
        domain_name:,
        in_select_email_flow:,
        **extra,
      )
    end

    # When a user views the add email address page
    # @param [Boolean] in_select_email_flow Whether email is being added as part of partner email
    # selection.
    def add_email_visit(in_select_email_flow:, **extra)
      track_event('Add Email Address Page Visited', in_select_email_flow:, **extra)
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # Tracks request for deletion of email address
    def email_deletion_request(success:, error_details: nil, **extra)
      track_event(
        'Email Deletion Requested',
        success:,
        error_details:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # Tracks if Email Language is updated
    def email_language_updated(success:, error_details: nil, **extra)
      track_event(
        'Email Language: Updated',
        success:,
        error_details:,
        **extra,
      )
    end

    # Tracks if Email Language is visited
    def email_language_visited
      track_event('Email Language: Visited')
    end

    # Logs after an email is sent
    # @param [String] action type of email being sent
    # @param [String, nil] ses_message_id AWS SES Message ID
    # @param [Integer] email_address_id Database identifier for email address record
    def email_sent(action:, ses_message_id:, email_address_id:, **extra)
      track_event(
        'Email Sent',
        action: action,
        ses_message_id: ses_message_id,
        email_address_id: email_address_id,
        **extra,
      )
    end

    # @param [Boolean] success
    # Tracks request for resending confirmation for new emails to an account
    def resend_add_email_request(success:, **extra)
      track_event(
        'Resend Add Email Requested',
        success: success,
        **extra,
      )
    end
  end
end
