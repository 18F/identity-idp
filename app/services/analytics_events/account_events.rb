# frozen_string_literal: true

module AnalyticsEvents
  module AccountEvents

    # When a user views the account page
    def account_visit
      track_event('Account Page Visited')
    end

    # Tracks When users visit the add phone page
    def add_phone_setup_visit
      track_event(
        'Phone Setup Visited',
      )
    end

    # Tracks when the user creates a set of backup mfa codes.
    # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
    # @param [Boolean] in_account_creation_flow Whether user is going through creation flow
    def backup_code_created(enabled_mfa_methods_count:, in_account_creation_flow:, **extra)
      track_event(
        'Backup Code Created',
        enabled_mfa_methods_count:,
        in_account_creation_flow:,
        **extra,
      )
    end

    # Tracks when the user visits the Backup Code Regenerate page.
    # @param [Boolean] in_account_creation_flow whether user is going through creation flow
    def backup_code_regenerate_visit(in_account_creation_flow:, **extra)
      track_event('Backup Code Regenerate Visited', in_account_creation_flow:, **extra)
    end

    # @param [Boolean] has_codes Whether the user still has access to their backup codes.
    # Tracks when the user submits to confirm whether they still have access to their backup codes
    # when signing in for the first time in at least 5 months.
    def backup_code_reminder_submitted(has_codes:, **extra)
      track_event(:backup_code_reminder_submitted, has_codes:, **extra)
    end

    # Tracks when the user is prompted to confirm that they still have access to their backup codes
    # when signing in for the first time in at least 5 months.
    def backup_code_reminder_visited
      track_event(:backup_code_reminder_visited)
    end

    # Track user creating new BackupCodeSetupForm, record form submission Hash
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] mfa_method_counts Hash of MFA method with the number of that method on the account
    # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
    # @param [Boolean] in_account_creation_flow Whether page is visited as part of account creation
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    def backup_code_setup_visit(
      success:,
      mfa_method_counts:,
      enabled_mfa_methods_count:,
      in_account_creation_flow:,
      error_details: nil,
      **extra
    )
      track_event(
        'Backup Code Setup Visited',
        success:,
        error_details:,
        mfa_method_counts:,
        enabled_mfa_methods_count:,
        in_account_creation_flow:,
        **extra,
      )
    end

    # A user that had a broken personal key was routed to a page to regenerate their personal key,
    # so that they no longer have a broken one
    def broken_personal_key_regenerated
      track_event('Broken Personal Key: Regenerated')
    end

    # User visits the "Are you sure you want to cancel and exit" page
    def completions_cancellation_visited
      track_event(:completions_cancellation_visited)
    end

    # User was logged out due to an existing active session
    def concurrent_session_logout
      track_event(:concurrent_session_logout)
    end

    # User visits the connected accounts page
    def connected_accounts_page_visited
      track_event(:connected_accounts_page_visited)
    end

    # @param [Boolean] required_password_change if user forced to change password
    # When a user views the edit password page
    def edit_password_visit(required_password_change: false, **extra)
      track_event(
        'Edit Password Page Visited',
        required_password_change: required_password_change,
        **extra,
      )
    end

    # User visited the events page
    def events_visit
      track_event('Events Page Visited')
    end

    def fingerprints_rotated
      track_event(:fingerprints_rotated)
    end

    # The user chose to "forget all browsers"
    def forget_all_browsers_submitted
      track_event('Forget All Browsers Submitted')
    end

    # The user visited the "forget all browsers" page
    def forget_all_browsers_visited
      track_event('Forget All Browsers Visited')
    end

    # Tracks when fraud clears duplicate profile
    # @param [Boolean] success Whether the profile was successfully cleared
    # @param [Hash] errors Errors resulting from clearing
    def one_account_clear_duplicate_profile(success:, errors:, **extra)
      track_event(
        :one_account_clear_duplicate_profile,
        success: success,
        errors: errors,
        **extra,
      )
    end

    # Tracks when the fraud investigation is inconclusive
    # @param [Boolean] success Whether the duplicate was successfully closed
    # @param [Hash] errors Errors resulting from clearing
    def one_account_close_inconclusive_duplicate(success:, errors:, **extra)
      track_event(
        :one_account_close_inconclusive_duplicate,
        success: success,
        errors: errors,
        **extra,
      )
    end

    # Tracks when fraud deactivates duplicate profile
    # @param [Boolean] success Whether the profile was successfully deactivated
    # @param [Hash] errors Errors resulting from deactivation
    def one_account_deactivate_duplicate_profile(success:, errors:, **extra)
      track_event(
        :one_account_deactivate_duplicate_profile,
        success: success,
        errors: errors,
        **extra,
      )
    end

    # Tracks when a user that had duplicate profiles is closed
    # @param [Integer] time_taken_in_minutes time taken to resolve the duplicate profiles in minutes
    def one_account_duplicate_profile_closed(time_taken_in_minutes:, **extra)
      track_event(
        :one_account_duplicate_profile_closed,
        time_taken_in_minutes: time_taken_in_minutes,
        **extra,
      )
    end

    # Tracks when a duplicate profile is created for a user
    def one_account_duplicate_profile_created
      track_event(:one_account_duplicate_profile_created)
    end

    # When there's an error creating duplicate profile set
    # @param [String] service_provider The service provider that initiated the creation
    # @param [Array<Integer>] profile_ids The profile IDs that were attempted to be added
    # @param [String] error_message The error message returned from the operation
    def one_account_duplicate_profile_creation_failed(
      service_provider:,
      profile_ids:,
      error_message:,
      **extra
    )
      track_event(
        :one_account_duplicate_profile_creation_failed,
        service_provider: service_provider,
        profile_ids: profile_ids,
        error_message: error_message,
        **extra,
      )
    end

    # Tracks when a duplicate profile set is reopened for profiles
    # @param [Integer] duplicate_profile_set_id The ID of the duplicate profile set reopened
    def one_account_duplicate_profile_reopened(duplicate_profile_set_id:, **extra)
      track_event(
        :one_account_duplicate_profile_reopened,
        duplicate_profile_set_id: duplicate_profile_set_id,
        **extra,
      )
    end

    # Tracks when a duplicate profile object is updated
    def one_account_duplicate_profile_updated
      track_event(:one_account_duplicate_profile_updated)
    end

    # Tracks when user with duplicate profiles lands on page asking them to call the contact center
    # @param [String] source The link that the user followed to visit the page
    def one_account_duplicate_profiles_please_call_visited(source:, **extra)
      track_event(:one_account_duplicate_profiles_please_call_visited, source: source, **extra)
    end

    # Tracks when user lands on page notifying them multiple profiles contain same information
    # @param [String] source how the user came through to the page
    def one_account_duplicate_profiles_warning_page_visited(source:, **extra)
      track_event(:one_account_duplicate_profiles_warning_page_visited, source: source, **extra)
    end

    # Tracks when a user self services their duplicate account issue
    # @param [Symbol] source where the self service occurs (account_management, account_reset, etc...)
    # @param [String] service_provider The service provider  of the duplicate profile set serviced
    # @param [Integer] associated_profiles_count The number of associated profiles for the set
    # @param [Integer] dupe_profile_set_id The ID of the duplicate profile set
    def one_account_self_service(
          source:,
          service_provider:,
          associated_profiles_count:,
          dupe_profile_set_id:,
          **extra
        )
      track_event(
        :one_account_self_service,
        source: source,
        service_provider: service_provider,
        associated_profiles_count: associated_profiles_count,
        dupe_profile_set_id: dupe_profile_set_id,
        **extra,
      )
    end

    # Account profile reactivation submitted
    def reactivate_account_submit
      track_event('Reactivate Account Submitted')
    end

    # Submission event for the "verify password" page the user sees after entering their personal key.
    # @param [Boolean] success Whether the form was submitted successfully.
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    def reactivate_account_verify_password_submitted(success:, error_details: nil, **extra)
      track_event(:reactivate_account_verify_password_submitted, success:, error_details:, **extra)
    end

    # Visit event for the "verify password" page the user sees after entering their personal key.
    def reactivate_account_verify_password_visited(**extra)
      track_event(:reactivate_account_verify_password_visited, **extra)
    end

    # Account profile reactivation page visited
    def reactivate_account_visit
      track_event('Reactivate Account Visited')
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Integer] enabled_mfa_methods_count
    # @param [Integer] selected_mfa_count
    # @param ['voice', 'auth_app'] selection
    # Tracks when the the user has selected and submitted MFA auth methods on user registration
    def user_registration_2fa_setup(
      success:,
      error_details: nil,
      selected_mfa_count: nil,
      enabled_mfa_methods_count: nil,
      selection: nil,
      **extra
    )
      track_event(
        'User Registration: 2FA Setup',
        success:,
        error_details:,
        selected_mfa_count:,
        enabled_mfa_methods_count:,
        selection:,
        **extra,
      )
    end

    # Tracks when user visits MFA selection page
    # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
    # @param [Boolean] gov_or_mil_email Whether registered user has government email
    def user_registration_2fa_setup_visit(
      enabled_mfa_methods_count:,
      gov_or_mil_email:,
      **extra
    )
      track_event(
        'User Registration: 2FA Setup visited',
        enabled_mfa_methods_count:,
        gov_or_mil_email:,
        **extra,
      )
    end

    # User registration has been handed off to agency page
    # @param [Boolean] ial2 Whether the user registration was for a verified identity
    # @param [Integer] ialmax Whether the user registration was for an IALMax request
    # @param [String] service_provider_name The friendly name of the service provider
    # @param ['account-page','agency-page'] page_occurence Where the user concluded registration
    # @param ['new_sp','new_attributes','reverified_after_consent'] needs_completion_screen_reason The
    #   reason for the consent screen being shown
    # @param [Boolean] in_account_creation_flow Whether user is going through account creation
    # @param [Array] sp_session_requested_attributes Attributes requested by the service provider
    # @param [String, nil] in_person_proofing_status In person proofing status
    # @param [String, nil] doc_auth_result The doc auth result
    def user_registration_agency_handoff_page_visit(
      ial2:,
      service_provider_name:,
      page_occurence:,
      needs_completion_screen_reason:,
      in_account_creation_flow:,
      sp_session_requested_attributes:,
      ialmax: nil,
      in_person_proofing_status: nil,
      doc_auth_result: nil,
      **extra
    )
      track_event(
        'User registration: agency handoff visited',
        ial2:,
        ialmax:,
        service_provider_name:,
        page_occurence:,
        needs_completion_screen_reason:,
        in_account_creation_flow:,
        sp_session_requested_attributes:,
        in_person_proofing_status:,
        doc_auth_result:,
        **extra,
      )
    end

    # Tracks when user cancels registration
    # @param [String] request_came_from the controller/action the request came from
    def user_registration_cancellation(request_came_from:, **extra)
      track_event(
        'User registration: cancellation visited',
        request_came_from: request_came_from,
        **extra,
      )
    end

    # Tracks when user completes registration
    # @param [Boolean] ial2 Whether the user registration was for a verified identity
    # @param [Boolean] ialmax Whether the user registration was for an IALMax request
    # @param [String] service_provider_name The friendly name of the service provider
    # @param ['account-page','agency-page'] page_occurence Where the user concluded registration
    # @param ['new_sp','new_attributes','reverified_after_consent'] needs_completion_screen_reason The
    #   reason for the consent screen being shown
    # @param [Array] sp_session_requested_attributes Attributes requested by the service provider
    # @param [Boolean] in_account_creation_flow Whether user is going through account creation flow
    # @param [String, nil] disposable_email_domain Disposable email domain used for registration
    # @param [String, nil] in_person_proofing_status In person proofing status
    # @param [String, nil] doc_auth_result The doc auth result
    def user_registration_complete(
      ial2:,
      service_provider_name:,
      page_occurence:,
      in_account_creation_flow:,
      needs_completion_screen_reason:,
      sp_session_requested_attributes:,
      ialmax: nil,
      disposable_email_domain: nil,
      in_person_proofing_status: nil,
      doc_auth_result: nil,
      **extra
    )
      track_event(
        'User registration: complete',
        ial2:,
        ialmax:,
        service_provider_name:,
        page_occurence:,
        in_account_creation_flow:,
        needs_completion_screen_reason:,
        sp_session_requested_attributes:,
        disposable_email_domain:,
        in_person_proofing_status:,
        doc_auth_result:,
        **extra,
      )
    end

    # Tracks when user submits registration email
    # @param [Boolean] success Whether form validation was successful
    # @param [Boolean] rate_limited Whether form submission was prevented by rate-limiting
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] user_id ID of user associated with existing user, or current user
    # @param [Boolean] email_already_exists Whether an account with the email address already exists
    # @param [String] domain_name Domain name of email address submitted
    # @param [String] email_language Preferred language for email communication
    def user_registration_email(
      success:,
      rate_limited:,
      user_id:,
      email_already_exists:,
      domain_name:,
      email_language:,
      error_details: nil,
      **extra
    )
      track_event(
        'User Registration: Email Submitted',
        success:,
        rate_limited:,
        error_details:,
        user_id:,
        email_already_exists:,
        domain_name:,
        email_language:,
        **extra,
      )
    end

    # Tracks when user confirms registration email
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] user_id
    def user_registration_email_confirmation(
      success:,
      errors: nil,
      error_details: nil,
      user_id: nil,
      **extra
    )
      track_event(
        'User Registration: Email Confirmation',
        success:,
        errors:,
        error_details:,
        user_id:,
        **extra,
      )
    end

    # Tracks when user visits enter email page
    def user_registration_enter_email_visit
      track_event('User Registration: enter email visited')
    end

    # @param [Boolean] success
    # @param [Hash] mfa_method_counts Hash of MFA method with the number of that method on the account
    # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
    # @param [Boolean] second_mfa_reminder_conversion Whether it is a result of second MFA reminder.
    # @param [Boolean] in_account_creation_flow Whether user is going through creation flow
    # Tracks when a user has completed MFA setup
    def user_registration_mfa_setup_complete(
      success:,
      mfa_method_counts:,
      enabled_mfa_methods_count:,
      in_account_creation_flow: nil,
      second_mfa_reminder_conversion: nil,
      **extra
    )
      track_event(
        'User Registration: MFA Setup Complete',
        success:,
        mfa_method_counts:,
        enabled_mfa_methods_count:,
        in_account_creation_flow:,
        second_mfa_reminder_conversion:,
        **extra,
      )
    end

    # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
    # Tracks when user visits the phone setup step during registration
    def user_registration_phone_setup_visit(enabled_mfa_methods_count:, **extra)
      track_event(
        'User Registration: phone setup visited',
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        **extra,
      )
    end

    # Tracks when user skips Suggest Another MFA Page
    def user_registration_suggest_another_mfa_notice_skipped
      track_event('User Registration: Suggest Another MFA Notice Skipped')
    end

    # Tracks when user visits Suggest Another MFA Page
    def user_registration_suggest_another_mfa_notice_visited
      track_event('User Registration: Suggest Another MFA Notice visited')
    end

    # @param [String] mfa_method
    # Tracks when the the user fully registered by submitting their first MFA method into the system
    def user_registration_user_fully_registered(mfa_method:, **extra)
      track_event('User Registration: User Fully Registered', mfa_method:, **extra)
    end

    # Tracks when user reinstated
    # @param [Boolean] success
    # @param [String] error_message
    def user_reinstated(success:, error_message: nil, **extra)
      track_event('User Suspension: Reinstated', success:, error_message:, **extra)
    end

    # Tracks when user suspended
    # @param [Boolean] success
    # @param [String] error_message
    def user_suspended(success:, error_message: nil, **extra)
      track_event('User Suspension: Suspended', success:, error_message:, **extra)
    end

    # Tracks when the user is suspended and attempts to sign in, triggering the please call page.
    def user_suspended_please_call_visited(**extra)
      track_event(
        'User Suspension: Please call visited',
        **extra,
      )
    end

    # We sent an email to the user confirming that they will remain suspended
    def user_suspension_confirmed
      track_event(:user_suspension_confirmed)
    end
  end
end
