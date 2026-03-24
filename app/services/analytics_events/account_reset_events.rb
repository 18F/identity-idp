# frozen_string_literal: true

module AnalyticsEvents
  module AccountResetEvents

    # @param [Boolean] success
    # When a user submits a form to delete their account
    def account_delete_submitted(success:, **extra)
      track_event('Account Delete submitted', success: success, **extra)
    end

    # When a user visits the page to delete their account
    def account_delete_visited
      track_event('Account Delete visited')
    end

    # @param [String] request_came_from the controller/action the request came from
    # When a user deletes their account
    def account_deletion(request_came_from:, **extra)
      track_event('Account Deletion Requested', request_came_from: request_came_from, **extra)
    end

    # @identity.idp.previous_event_name Account Reset
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] user_id
    # @param [String, nil] message_id from AWS Pinpoint API
    # @param [String, nil] request_id from AWS Pinpoint API
    # An account reset was cancelled
    def account_reset_cancel(
      success:,
      user_id:,
      errors: nil,
      error_details: nil,
      message_id: nil,
      request_id: nil,
      **extra
    )
      track_event(
        'Account Reset: cancel',
        success:,
        errors:,
        error_details:,
        user_id:,
        message_id:,
        request_id:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name Account Reset
    # @param [String] user_id
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # Validates the token used for cancelling an account reset
    def account_reset_cancel_token_validation(
      user_id:,
      success:,
      error_details: nil,
      **extra
    )
      track_event(
        'Account Reset: cancel token validation',
        user_id:,
        success:,
        error_details:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name Account Reset
    # @param [Boolean] success Whether form validation was successful
    # @param [String] user_id
    # @param [Integer, nil] account_age_in_days number of days since the account was confirmed
    # @param [Time] account_confirmed_at date that account creation was confirmed
    #   (rounded) or nil if the account was not confirmed
    # @param [Hash] mfa_method_counts Hash of MFA method with the number of that method on the account
    # @param [Boolean] identity_verified if the deletion occurs on a verified account
    # @param [String, nil] profile_idv_level shows how verified the user is
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # An account has been deleted through the account reset flow
    def account_reset_delete(
      success:,
      user_id:,
      account_age_in_days:,
      account_confirmed_at:,
      mfa_method_counts:,
      identity_verified:,
      profile_idv_level: nil,
      error_details: nil,
      **extra
    )
      track_event(
        'Account Reset: delete',
        success:,
        user_id:,
        account_age_in_days:,
        account_confirmed_at:,
        mfa_method_counts:,
        profile_idv_level:,
        identity_verified:,
        error_details:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name Account Reset
    # @param [String] user_id
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # Validates the granted token for account reset
    def account_reset_granted_token_validation(
      success:,
      error_details: nil,
      user_id: nil,
      **extra
    )
      track_event(
        'Account Reset: granted token validation',
        success:,
        error_details:,
        user_id:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name Account Reset
    # @param [Integer] count number of email notifications sent
    # Account reset was performed, logs the number of email notifications sent
    def account_reset_notifications(count:, **extra)
      track_event('Account Reset: notifications', count: count, **extra)
    end

    # Tracks users visiting the recovery options page
    def account_reset_recovery_options_visit
      track_event('Account Reset: Recovery Options Visited')
    end

    # @identity.idp.previous_event_name Account Reset
    # @param [Boolean] success
    # @param [Boolean] sms_phone does the user have a phone factor configured?
    # @param [Boolean] totp does the user have an authentication app as a 2FA option?
    # @param [Boolean] piv_cac does the user have PIV/CAC as a 2FA option?
    # @param [Integer] email_addresses number of email addresses the user has
    # @param [String, nil] message_id from AWS Pinpoint API
    # @param [String, nil] request_id from AWS Pinpoint API
    # An account reset has been requested
    def account_reset_request(
      success:,
      sms_phone:,
      totp:,
      piv_cac:,
      email_addresses:,
      request_id: nil,
      message_id: nil,
      **extra
    )
      track_event(
        'Account Reset: request',
        success:,
        sms_phone:,
        totp:,
        piv_cac:,
        email_addresses:,
        request_id:,
        message_id:,
        **extra,
      )
    end

    # User visited the account deletion and reset page
    def account_reset_visit
      track_event('Account deletion and reset visited')
    end

    # Tracks users going back or cancelling acoount recovery
    def cancel_account_reset_recovery
      track_event('Account Reset: Cancel Account Recovery Options')
    end

    # Pending account reset cancelled
    def pending_account_reset_cancelled
      track_event('Pending account reset cancelled')
    end

    # Pending account reset visited
    def pending_account_reset_visited
      track_event('Pending account reset visited')
    end
  end
end
