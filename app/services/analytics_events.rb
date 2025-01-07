# frozen_string_literal: true

#  ______________________________________
# / Adding something new in here? Please \
# \ keep methods sorted alphabetically.  /
#  --------------------------------------
#         \   ^__^
#          \  (oo)\_______
#             (__)\       )\/\
#                 ||----w |
#                 ||     ||

module AnalyticsEvents
  # @param [Boolean] success Check whether threatmetrix succeeded properly.
  # @param [String] transaction_id Vendor-specific transaction ID for the request.
  # @param [String, nil] client Client user was directed from when creating account
  # @param [array<String>, nil] errors error response from api call
  # @param [String, nil] exception Error exception from api call
  # @param [Boolean] timed_out set whether api call timed out
  # @param [String] review_status TMX decision on the user
  # @param [String] account_lex_id LexID associated with the response.
  # @param [String] session_id Session ID associated with response
  # @param [Hash] response_body total response body for api call
  # Result when threatmetrix is completed for account creation and result
  def account_creation_tmx_result(
    client:,
    success:,
    errors:,
    exception:,
    timed_out:,
    transaction_id:,
    review_status:,
    account_lex_id:,
    session_id:,
    response_body:,
    **extra
  )
    track_event(
      :account_creation_tmx_result,
      client:,
      success:,
      errors:,
      exception:,
      timed_out:,
      transaction_id:,
      review_status:,
      account_lex_id:,
      session_id:,
      response_body:,
      **extra,
    )
  end

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
    errors:,
    user_id:,
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
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # Validates the token used for cancelling an account reset
  def account_reset_cancel_token_validation(
    user_id:,
    success:,
    errors:,
    error_details: nil,
    **extra
  )
    track_event(
      'Account Reset: cancel token validation',
      user_id:,
      success:,
      errors:,
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
  # @param [Hash] errors Errors resulting from form validation
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
    errors:,
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
      errors:,
      error_details:,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account Reset
  # @param [String] user_id
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # Validates the granted token for account reset
  def account_reset_granted_token_validation(
    success:,
    errors:,
    error_details: nil,
    user_id: nil,
    **extra
  )
    track_event(
      'Account Reset: granted token validation',
      success:,
      errors:,
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
  # @param [Hash] errors Errors resulting from form validation
  # @param [Boolean] sms_phone does the user have a phone factor configured?
  # @param [Boolean] totp does the user have an authentication app as a 2FA option?
  # @param [Boolean] piv_cac does the user have PIV/CAC as a 2FA option?
  # @param [Integer] email_addresses number of email addresses the user has
  # @param [String, nil] message_id from AWS Pinpoint API
  # @param [String, nil] request_id from AWS Pinpoint API
  # An account reset has been requested
  def account_reset_request(
    success:,
    errors:,
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
      errors:,
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

  # When a user views the account page
  def account_visit
    track_event('Account Page Visited')
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] user_id User the email is linked to
  # @param [Boolean] from_select_email_flow Whether email was added as part of partner email
  #   selection.
  # A user has clicked the confirmation link in an email
  def add_email_confirmation(
    user_id:,
    success:,
    errors:,
    from_select_email_flow:,
    error_details: nil,
    **extra
  )
    track_event(
      'Add Email: Email Confirmation',
      user_id:,
      success:,
      errors:,
      error_details:,
      from_select_email_flow:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] domain_name Domain name of email address submitted
  # @param [Boolean] in_select_email_flow Whether email is being added as part of partner email
  #   selection.
  # Tracks request for adding new emails to an account
  def add_email_request(
    success:,
    errors:,
    domain_name:,
    in_select_email_flow:,
    error_details: nil,
    **extra
  )
    track_event(
      'Add Email Requested',
      success:,
      errors:,
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

  # Tracks When users visit the add phone page
  def add_phone_setup_visit
    track_event(
      'Phone Setup Visited',
    )
  end

  # @identity.idp.previous_event_name TOTP: User Disabled
  # Tracks when a user deletes their auth app from account
  # @param [Boolean] success
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] configuration_id
  def auth_app_delete_submitted(
    success:,
    configuration_id:,
    error_details: nil,
    **extra
  )
    track_event(
      :auth_app_delete_submitted,
      success:,
      error_details:,
      configuration_id:,
      **extra,
    )
  end

  # When a user updates name for auth app
  # @param [Boolean] success
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] configuration_id
  # Tracks when user submits a name change for an Auth App configuration
  def auth_app_update_name_submitted(
    success:,
    configuration_id:,
    error_details: nil,
    **extra
  )
    track_event(
      :auth_app_update_name_submitted,
      success:,
      error_details:,
      configuration_id:,
      **extra,
    )
  end

  # When a user views the "you are already signed in with the following email" screen
  def authentication_confirmation
    track_event('Authentication Confirmation')
  end

  # When a user views the "you are already signed in with the following email" screen and
  # continues with their existing logged-in email
  def authentication_confirmation_continue
    track_event('Authentication Confirmation: Continue selected')
  end

  # When a user views the "you are already signed in with the following email" screen and
  # signs out of their current logged in email to choose a different email
  def authentication_confirmation_reset
    track_event('Authentication Confirmation: Reset selected')
  end

  # @param [DateTime] fraud_rejection_at Date when profile was rejected
  # Tracks when a profile is automatically rejected due to being under review for 30 days
  def automatic_fraud_rejection(fraud_rejection_at:, **extra)
    track_event(
      'Fraud: Automatic Fraud Rejection',
      fraud_rejection_at: fraud_rejection_at,
      **extra,
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

  # Track user creating new BackupCodeSetupForm, record form submission Hash
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] mfa_method_counts Hash of MFA method with the number of that method on the account
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [Boolean] in_account_creation_flow Whether page is visited as part of account creation
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  def backup_code_setup_visit(
    success:,
    mfa_method_counts:,
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    errors:,
    error_details: nil,
    **extra
  )
    track_event(
      'Backup Code Setup Visited',
      success:,
      errors:,
      error_details:,
      mfa_method_counts:,
      enabled_mfa_methods_count:,
      in_account_creation_flow:,
      **extra,
    )
  end

  # A user that has been banned from an SP has authenticated, they are redirected
  # to a page showing them that they have been banned
  def banned_user_redirect
    track_event('Banned User redirected')
  end

  # A user that has been banned from an SP has authenticated, they have visited
  # a page showing them that they have been banned
  def banned_user_visited
    track_event('Banned User visited')
  end

  # A user that had a broken personal key was routed to a page to regenerate their personal key,
  # so that they no longer have a broken one
  def broken_personal_key_regenerated
    track_event('Broken Personal Key: Regenerated')
  end

  # Tracks users going back or cancelling acoount recovery
  def cancel_account_reset_recovery
    track_event('Account Reset: Cancel Account Recovery Options')
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

  # @param [String] redirect_url URL user was directed to
  # @param [String, nil] step which step
  # @param [String, nil] location which part of a step, if applicable
  # @param ["idv", String, nil] flow which flow
  # User was redirected to the login.gov contact page
  def contact_redirect(redirect_url:, step: nil, location: nil, flow: nil, **extra)
    track_event(
      'Contact Page Redirect',
      redirect_url: redirect_url,
      step: step,
      location: location,
      flow: flow,
      **extra,
    )
  end

  # New device sign-in alerts sent after expired notification timeframe
  # @param [Integer] count Number of emails sent
  def create_new_device_alert_job_emails_sent(count:, **extra)
    track_event(:create_new_device_alert_job_emails_sent, count:, **extra)
  end

  # @param [String] message the warning
  # @param [Array<String>] unknown_alerts Names of alerts not recognized by our code
  # @param [Hash] response_info Response payload
  # Logged when there is a non-user-facing error in the doc auth process, such as an unrecognized
  # field from a vendor
  def doc_auth_warning(message: nil, unknown_alerts: nil, response_info: nil, **extra)
    track_event(
      'Doc Auth Warning',
      message:,
      unknown_alerts:,
      response_info:,
      **extra,
    )
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

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Boolean] user_locked_out if the user is currently locked out of their second factor
  # @param [Boolean] rate_limited Whether the user has exceeded user IP rate limiting
  # @param [Boolean] valid_captcha_result Whether user passed the reCAPTCHA check or was exempt
  # @param [Boolean] captcha_validation_performed Whether a reCAPTCHA check was performed
  # @param [String] sign_in_failure_count represents number of prior login failures
  # @param [Boolean] sp_request_url_present if was an SP request URL in the session
  # @param [Boolean] remember_device if the remember device cookie was present
  # @param [Boolean, nil] new_device Whether the user is authenticating from a new device. Nil if
  #   the attempt was unsuccessful, since it cannot be known whether it's a new device.
  # Tracks authentication attempts at the email/password screen
  def email_and_password_auth(
    success:,
    user_locked_out:,
    rate_limited:,
    valid_captcha_result:,
    captcha_validation_performed:,
    sign_in_failure_count:,
    sp_request_url_present:,
    remember_device:,
    new_device:,
    error_details: nil,
    **extra
  )
    track_event(
      'Email and Password Authentication',
      success:,
      error_details:,
      user_locked_out:,
      rate_limited:,
      valid_captcha_result:,
      captcha_validation_performed:,
      sign_in_failure_count:,
      sp_request_url_present:,
      remember_device:,
      new_device:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # Tracks request for deletion of email address
  def email_deletion_request(success:, errors:, error_details: nil, **extra)
    track_event(
      'Email Deletion Requested',
      success:,
      errors:,
      error_details:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # Tracks if Email Language is updated
  def email_language_updated(success:, errors:, error_details: nil, **extra)
    track_event(
      'Email Language: Updated',
      success:,
      errors:,
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

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Time, nil] event_created_at timestamp for the event
  # @param [Time, nil] disavowed_device_last_used_at
  # @param [String, nil] disavowed_device_user_agent
  # @param [String, nil] disavowed_device_last_ip
  # @param [Integer, nil] event_id events table id
  # @param [String, nil] event_type (see Event#event_type)
  # @param [String, nil] event_ip ip address for the event
  # @param [String, nil] user_id UUID of the user
  # Tracks disavowed event
  def event_disavowal(
    success:,
    errors:,
    user_id:,
    error_details: nil,
    event_created_at: nil,
    disavowed_device_last_used_at: nil,
    disavowed_device_user_agent: nil,
    disavowed_device_last_ip: nil,
    event_id: nil,
    event_type: nil,
    event_ip: nil,
    **extra
  )
    track_event(
      'Event disavowal visited',
      success:,
      errors:,
      error_details:,
      event_created_at:,
      disavowed_device_last_used_at:,
      disavowed_device_user_agent:,
      disavowed_device_last_ip:,
      event_id:,
      event_type:,
      event_ip:,
      user_id:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Time, nil] event_created_at timestamp for the event
  # @param [Time, nil] disavowed_device_last_used_at
  # @param [String, nil] disavowed_device_user_agent
  # @param [String, nil] disavowed_device_last_ip
  # @param [Integer, nil] event_id events table id
  # @param [String, nil] event_type (see Event#event_type)
  # @param [String, nil] event_ip ip address for the event
  # @param [String, nil] user_id UUID of the user
  # Event disavowal password reset was performed
  def event_disavowal_password_reset(
    success:,
    errors:,
    user_id:,
    error_details: nil,
    event_created_at: nil,
    disavowed_device_last_used_at: nil,
    disavowed_device_user_agent: nil,
    disavowed_device_last_ip: nil,
    event_id: nil,
    event_type: nil,
    event_ip: nil,
    **extra
  )
    track_event(
      'Event disavowal password reset',
      success:,
      errors:,
      error_details:,
      event_created_at:,
      disavowed_device_last_used_at:,
      disavowed_device_user_agent:,
      disavowed_device_last_ip:,
      event_id:,
      event_type:,
      event_ip:,
      user_id:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Time, nil] event_created_at timestamp for the event
  # @param [Time, nil] disavowed_device_last_used_at
  # @param [String, nil] disavowed_device_user_agent
  # @param [String, nil] disavowed_device_last_ip
  # @param [Integer, nil] event_id events table id
  # @param [String, nil] event_type (see Event#event_type)
  # @param [String, nil] event_ip ip address for the event
  # An invalid disavowal token was clicked
  def event_disavowal_token_invalid(
    success:,
    errors:,
    error_details: nil,
    event_created_at: nil,
    disavowed_device_last_used_at: nil,
    disavowed_device_user_agent: nil,
    disavowed_device_last_ip: nil,
    event_id: nil,
    event_type: nil,
    event_ip: nil,
    **extra
  )
    track_event(
      'Event disavowal token invalid',
      success:,
      errors:,
      error_details:,
      event_created_at:,
      disavowed_device_last_used_at:,
      disavowed_device_user_agent:,
      disavowed_device_last_ip:,
      event_id:,
      event_type:,
      event_ip:,
      **extra,
    )
  end

  # User visited the events page
  def events_visit
    track_event('Events Page Visited')
  end

  # @param [String] redirect_url URL user was directed to
  # @param [String, nil] step which step
  # @param [String, nil] location which part of a step, if applicable
  # @param ["idv", String, nil] flow which flow
  # User was redirected to a page outside the IDP
  def external_redirect(redirect_url:, step: nil, location: nil, flow: nil, **extra)
    track_event(
      'External Redirect',
      redirect_url: redirect_url,
      step: step,
      location: location,
      flow: flow,
      **extra,
    )
  end

  # The user chose to "forget all browsers"
  def forget_all_browsers_submitted
    track_event('Forget All Browsers Submitted')
  end

  # The user visited the "forget all browsers" page
  def forget_all_browsers_visited
    track_event('Forget All Browsers Visited')
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] exception
  # @param [String] profile_fraud_review_pending_at
  # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
  # The user was passed by manual fraud review
  def fraud_review_passed(
    success:,
    errors:,
    exception:,
    profile_fraud_review_pending_at:,
    profile_age_in_seconds:,
    **extra
  )
    track_event(
      'Fraud: Profile review passed',
      success: success,
      errors: errors,
      exception: exception,
      profile_fraud_review_pending_at: profile_fraud_review_pending_at,
      profile_age_in_seconds: profile_age_in_seconds,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] exception
  # @param [String] profile_fraud_review_pending_at
  # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
  # The user was rejected by manual fraud review
  def fraud_review_rejected(
    success:,
    errors:,
    exception:,
    profile_fraud_review_pending_at:,
    profile_age_in_seconds:,
    **extra
  )
    track_event(
      'Fraud: Profile review rejected',
      success: success,
      errors: errors,
      exception: exception,
      profile_fraud_review_pending_at: profile_fraud_review_pending_at,
      profile_age_in_seconds: profile_age_in_seconds,
      **extra,
    )
  end

  # @param [Boolean] success Whether records were successfully uploaded
  # @param [String] exception The exception that occured if an exception did occur
  # @param [Number] gpo_confirmation_count The number of GPO Confirmation records uploaded
  # GPO confirmation records were uploaded for letter sends
  def gpo_confirmation_upload(
    success:,
    exception:,
    gpo_confirmation_count:,
    **extra
  )
    track_event(
      :gpo_confirmation_upload,
      success: success,
      exception: exception,
      gpo_confirmation_count: gpo_confirmation_count,
      **extra,
    )
  end

  # User visited sign-in URL from the "You've been successfully verified email" CTA button
  # @param issuer [String] the ServiceProvider.issuer
  # @param campaign_id [String] the email campaign ID
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  def idv_account_verified_cta_visited(
    issuer:,
    campaign_id:,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      :idv_account_verified_cta_visited,
      issuer:,
      campaign_id:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,

      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] isCameraSupported
  # @param [Boolean] success
  # @param [Boolean] use_alternate_sdk
  # @param [Boolean] liveness_checking_required
  # The Acuant SDK was loaded
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_acuant_sdk_loaded(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    isCameraSupported:,
    success:,
    use_alternate_sdk:,
    liveness_checking_required:,
    **extra
  )
    track_event(
      'Frontend: IdV: Acuant SDK loaded',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      isCameraSupported: isCameraSupported,
      success: success,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # @param [Boolean] success Whether form validation was successful
  # @param [Boolean] address_edited
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # User submitted an idv address
  def idv_address_submitted(
    success:,
    errors:,
    address_edited: nil,
    error_details: nil,
    **extra
  )
    track_event(
      'IdV: address submitted',
      success: success,
      errors: errors,
      address_edited: address_edited,
      error_details: error_details,
      **extra,
    )
  end

  # User visited idv address page
  def idv_address_visit(**extra)
    track_event('IdV: address visited', **extra)
  end

  # @param [String] acuantCaptureMode
  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [Boolean] assessment
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # @param [String] documentType
  # @param [Integer] dpi  dots per inch of image
  # @param [Integer] failedImageResubmission
  # @param [String] fingerprint fingerprint of the image added
  # @param [String] flow_path whether the user is in the hybrid or standard flow
  # @param [Integer] glare
  # @param [Integer] glareScoreThreshold
  # @param [Integer] height height of image added in pixels
  # @param [Boolean] isAssessedAsBlurry
  # @param [Boolean] isAssessedAsGlare
  # @param [Boolean] isAssessedAsUnsupported
  # @param [String] mimeType MIME type of image added
  # @param [Integer] moire
  # @param [Integer] sharpness
  # @param [Integer] sharpnessScoreThreshold
  # @param [Integer] size size of image added in bytes
  # @param [String] source
  # @param [Boolean] use_alternate_sdk
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [Integer] width width of image added in pixels
  # Back image was added in document capture
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_back_image_added(
    acuantCaptureMode:,
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    assessment:,
    captureAttempts:,
    documentType:,
    dpi:,
    failedImageResubmission:,
    fingerprint:,
    flow_path:,
    glare:,
    glareScoreThreshold:,
    height:,
    isAssessedAsBlurry:,
    isAssessedAsGlare:,
    isAssessedAsUnsupported:,
    mimeType:,
    moire:,
    sharpness:,
    sharpnessScoreThreshold:,
    size:,
    source:,
    use_alternate_sdk:,
    liveness_checking_required:,
    width:,
    **extra
  )
    track_event(
      'Frontend: IdV: back image added',
      acuantCaptureMode: acuantCaptureMode,
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      assessment: assessment,
      captureAttempts: captureAttempts,
      documentType: documentType,
      dpi: dpi,
      failedImageResubmission: failedImageResubmission,
      fingerprint: fingerprint,
      flow_path: flow_path,
      glare: glare,
      glareScoreThreshold: glareScoreThreshold,
      height: height,
      isAssessedAsBlurry: isAssessedAsBlurry,
      isAssessedAsGlare: isAssessedAsGlare,
      isAssessedAsUnsupported: isAssessedAsUnsupported,
      mimeType: mimeType,
      moire: moire,
      sharpness: sharpness,
      sharpnessScoreThreshold: sharpnessScoreThreshold,
      size: size,
      source: source,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
      width: width,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] isDrop
  # @param [Boolean] click_source
  # @param [Boolean] use_alternate_sdk
  # @param [Number] captureAttempts count of image capturing attempts
  # @param [String] liveness_checking_required Whether or not the selfie is required
  def idv_back_image_clicked(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    isDrop:,
    click_source:,
    use_alternate_sdk:,
    captureAttempts:,
    liveness_checking_required:,
    **extra
  )
    track_event(
      'Frontend: IdV: back image clicked',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      isDrop: isDrop,
      click_source: click_source,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
      captureAttempts: captureAttempts,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # @param [String] liveness_checking_required Whether or not the selfie is required
  def idv_barcode_warning_continue_clicked(liveness_checking_required:, **extra)
    track_event(
      'Frontend: IdV: barcode warning continue clicked',
      liveness_checking_required: liveness_checking_required,
      **extra,
    )
  end

  # @param [String] liveness_checking_required Whether or not the selfie is required
  def idv_barcode_warning_retake_photos_clicked(liveness_checking_required:, **extra)
    track_event(
      'Frontend: IdV: barcode warning retake photos clicked',
      liveness_checking_required: liveness_checking_required,
      **extra,
    )
  end

  # @param [String] initiating_service_provider The service provider the user needs to connect to
  # The user chose not to connect their account from the SP follow-up page
  def idv_by_mail_sp_follow_up_cancelled(initiating_service_provider:, **extra)
    track_event(
      :idv_by_mail_sp_follow_up_cancelled,
      initiating_service_provider:,
      **extra,
    )
  end

  # @param [String] initiating_service_provider The service provider the user needs to connect to
  # The user chose to connect their account from the SP follow-up page
  def idv_by_mail_sp_follow_up_submitted(initiating_service_provider:, **extra)
    track_event(
      :idv_by_mail_sp_follow_up_submitted,
      initiating_service_provider:,
      **extra,
    )
  end

  # @param [String] initiating_service_provider The service provider the user needs to connect to
  # The user visited the SP follow-up page
  def idv_by_mail_sp_follow_up_visited(initiating_service_provider:, **extra)
    track_event(
      :idv_by_mail_sp_follow_up_visited,
      initiating_service_provider:,
      **extra,
    )
  end

  # @param [Hash] error
  def idv_camera_info_error(error:, **_extra)
    track_event(:idv_camera_info_error, error: error)
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Array] camera_info Information on the users cameras max resolution
  #   as captured by the browser
  def idv_camera_info_logged(flow_path:, camera_info:, **_extra)
    track_event(
      :idv_camera_info_logged, flow_path: flow_path, camera_info: camera_info
    )
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The user confirmed their choice to cancel going through IDV
  def idv_cancellation_confirmed(
    step:,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: cancellation confirmed',
      step: step,
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [boolean,nil] cancelled_enrollment Whether the user's IPP enrollment has been canceled
  # @param [String,nil] enrollment_code IPP enrollment code
  # @param [Integer,nil] enrollment_id ID of the associated IPP enrollment record
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The user chose to go back instead of cancel IDV
  def idv_cancellation_go_back(
    step:,
    proofing_components: nil,
    cancelled_enrollment: nil,
    enrollment_code: nil,
    enrollment_id: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: cancellation go back',
      step: step,
      proofing_components: proofing_components,
      cancelled_enrollment: cancelled_enrollment,
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # @param [String] request_came_from the controller and action from the
  #   source such as "users/sessions#new"
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The user clicked cancel during IDV (presented with an option to go back or confirm)
  def idv_cancellation_visited(
    step:,
    request_came_from:,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: cancellation visited',
      step: step,
      request_came_from: request_came_from,
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] use_alternate_sdk
  # @param [Boolean] liveness_checking_required
  # @param [Integer] submit_attempts Times that user has tried submitting document capture
  def idv_capture_troubleshooting_dismissed(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    use_alternate_sdk:,
    liveness_checking_required:,
    submit_attempts:,
    **extra
  )
    track_event(
      'Frontend: IdV: Capture troubleshooting dismissed',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
      submit_attempts: submit_attempts,
      **extra,
    )
  end

  # The user checked or unchecked the "By checking this box..." checkbox on the idv agreement step.
  # (This is a frontend event.)
  # @param [Boolean] checked Whether the user checked the checkbox
  def idv_consent_checkbox_toggled(checked:, **extra)
    track_event(
      'IdV: consent checkbox toggled',
      checked: checked,
      **extra,
    )
  end

  # User has consented to share information with document upload and may
  # view the "hybrid handoff" step next unless "skip_hybrid_handoff" param is true
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_agreement_submitted(
    success:,
    errors:,
    step:,
    analytics_id:,
    opted_in_to_in_person_proofing: nil,
    error_details: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth agreement submitted',
      success:,
      errors:,
      error_details:,
      step:,
      analytics_id:,
      acuant_sdk_upgrade_ab_test_bucket:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # User visits IdV agreement step
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_agreement_visited(
    step:,
    analytics_id:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth agreement visited',
      step:,
      analytics_id:,
      acuant_sdk_upgrade_ab_test_bucket:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] liveness_checking_required Whether facial match check is required
  def idv_doc_auth_capture_complete_visited(
    step:,
    analytics_id:,
    flow_path:,
    liveness_checking_required:,
    **extra
  )
    track_event(
      'IdV: doc auth capture_complete visited',
      step:,
      analytics_id:,
      flow_path:,
      liveness_checking_required:,
      **extra,
    )
  end

  # User returns from Socure document capture, but is waiting on a result to be fetched
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] liveness_checking_required Whether facial match check is required
  # @param [Boolean] selfie_check_required Whether facial match check is required
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  def idv_doc_auth_document_capture_polling_wait_visited(
    flow_path:,
    step:,
    analytics_id:,
    liveness_checking_required:,
    selfie_check_required:,
    redo_document_capture: nil,
    skip_hybrid_handoff: nil,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    **extra
  )
    track_event(
      :idv_doc_auth_document_capture_polling_wait_visited,
      flow_path:,
      step:,
      analytics_id:,
      redo_document_capture:,
      skip_hybrid_handoff:,
      liveness_checking_required:,
      selfie_check_required:,
      opted_in_to_in_person_proofing:,
      acuant_sdk_upgrade_ab_test_bucket:,
      **extra,
    )
  end

  # User submits IdV document capture step
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] liveness_checking_required Whether facial match check is required
  # @param [Boolean] selfie_check_required Whether facial match check is required
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
  #   warning
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # @param [Boolean] stored_result_present Whether a stored result was present
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_document_capture_submitted(
    success:,
    errors:,
    step:,
    analytics_id:,
    liveness_checking_required:,
    selfie_check_required:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    redo_document_capture: nil,
    skip_hybrid_handoff: nil,
    stored_result_present: nil,
    **extra
  )
    track_event(
      'IdV: doc auth document_capture submitted',
      success:,
      errors:,
      step:,
      analytics_id:,
      redo_document_capture:,
      skip_hybrid_handoff:,
      liveness_checking_required:,
      selfie_check_required:,
      acuant_sdk_upgrade_ab_test_bucket:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      stored_result_present:,
      **extra,
    )
  end

  # User visits IdV document capture step
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
  #   warning
  # @param [Boolean] liveness_checking_required Whether facial match check is required
  # @param [Boolean] selfie_check_required Whether facial match check is required
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_document_capture_visited(
    step:,
    analytics_id:,
    liveness_checking_required:,
    selfie_check_required:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    redo_document_capture: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth document_capture visited',
      flow_path:,
      step:,
      analytics_id:,
      redo_document_capture:,
      skip_hybrid_handoff:,
      liveness_checking_required:,
      selfie_check_required:,
      opted_in_to_in_person_proofing:,
      acuant_sdk_upgrade_ab_test_bucket:,
      **extra,
    )
  end

  # @param [String] step_name which step the user was on
  # @param [Integer] remaining_submit_attempts how many attempts the user has left before
  #                  we rate limit them (previously called "remaining_attempts")
  # The user visited an error page due to an encountering an exception talking to a proofing vendor
  def idv_doc_auth_exception_visited(step_name:, remaining_submit_attempts:, **extra)
    track_event(
      'IdV: doc auth exception visited',
      step_name: step_name,
      remaining_submit_attempts: remaining_submit_attempts,
      **extra,
    )
  end

  # @param [String] side the side of the image submission
  # @param [Integer] submit_attempts Times that user has tried submitting (previously called
  #   "attempts")
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [String] front_image_fingerprint Fingerprint of front image data
  # @param [String] back_image_fingerprint Fingerprint of back image data
  # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
  def idv_doc_auth_failed_image_resubmitted(
    side:,
    remaining_submit_attempts:,
    flow_path:,
    liveness_checking_required:,
    submit_attempts:,
    front_image_fingerprint:,
    back_image_fingerprint:,
    selfie_image_fingerprint:,
    **extra
  )
    track_event(
      'IdV: failed doc image resubmitted',
      side:,
      remaining_submit_attempts:,
      flow_path:,
      liveness_checking_required:,
      submit_attempts:,
      front_image_fingerprint:,
      back_image_fingerprint:,
      selfie_image_fingerprint:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [String] selection Selection form parameter
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_how_to_verify_submitted(
    success:,
    errors:,
    step:,
    analytics_id:,
    skip_hybrid_handoff:,
    opted_in_to_in_person_proofing: nil,
    selection: nil,
    error_details: nil,
    **extra
  )
    track_event(
      :idv_doc_auth_how_to_verify_submitted,
      success:,
      errors:,
      error_details:,
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      selection:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_how_to_verify_visited(
    step:,
    analytics_id:,
    skip_hybrid_handoff:,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      :idv_doc_auth_how_to_verify_visited,
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # The "hybrid handoff" step: Desktop user has submitted their choice to
  # either continue via desktop ("document_capture" destination) or switch
  # to mobile phone ("send_link" destination) to perform document upload.
  # @identity.idp.previous_event_name IdV: doc auth upload submitted
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
  #   warning
  # @param [Boolean] selfie_check_required Whether facial match check is required
  # @param ["document_capture","send_link"] destination Where user is sent after submission
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Hash] telephony_response Response from Telephony gem
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_hybrid_handoff_submitted(
    success:,
    errors:,
    step:,
    analytics_id:,
    redo_document_capture:,
    selfie_check_required:,
    destination:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    telephony_response: nil,
    **extra
  )
    track_event(
      'IdV: doc auth hybrid handoff submitted',
      success:,
      errors:,
      step:,
      analytics_id:,
      redo_document_capture:,
      skip_hybrid_handoff:,
      selfie_check_required:,
      acuant_sdk_upgrade_ab_test_bucket:,
      opted_in_to_in_person_proofing:,
      destination:,
      flow_path:,
      telephony_response:,
      **extra,
    )
  end

  # Desktop user has reached the above "hybrid handoff" view
  # @identity.idp.previous_event_name IdV: doc auth upload visited
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
  #   warning
  # @param [Boolean] selfie_check_required Whether facial match check is required
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_hybrid_handoff_visited(
    step:,
    analytics_id:,
    redo_document_capture:,
    selfie_check_required:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth hybrid handoff visited',
      step:,
      analytics_id:,
      redo_document_capture:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      selfie_check_required:,
      acuant_sdk_upgrade_ab_test_bucket:,
      **extra,
    )
  end

  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @identity.idp.previous_event_name IdV: doc auth send_link submitted
  def idv_doc_auth_link_sent_submitted(
    step:,
    analytics_id:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth link_sent submitted',
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      **extra,
    )
  end

  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_link_sent_visited(
    step:,
    analytics_id:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth link_sent visited',
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      **extra,
    )
  end

  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [Number] previous_ssn_edit_distance The edit distance to the previous submitted SSN
  def idv_doc_auth_redo_ssn_submitted(
    step:,
    analytics_id:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    previous_ssn_edit_distance: nil,
    **extra
  )
    track_event(
      'IdV: doc auth redo_ssn submitted',
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      previous_ssn_edit_distance:,
      **extra,
    )
  end

  # User is shown the Socure timeout error page
  # @param [String] error_code The type of error that occurred
  # @param [Integer] remaining_submit_attempts The number of remaining attempts to submit
  # @param [Boolean] skip_hybrid_handoff Whether the user skipped the hybrid handoff A/B test
  # @param [Boolean] opted_in_to_in_person_proofing Whether the user opted into in-person proofing
  def idv_doc_auth_socure_error_visited(
    error_code:,
    remaining_submit_attempts:,
    skip_hybrid_handoff: nil,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      :idv_doc_auth_socure_error_visited,
      error_code:,
      remaining_submit_attempts:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # @param [String] created_at The created timestamp received from Socure
  # @param [String] customer_user_id The customerUserId received from Socure
  # @param [String] docv_transaction_token The docvTransactionToken received from Socure
  # @param [String] event_type The eventType received from Socure
  # @param [String] reference_id The referenceId received from Socure
  # @param [String] user_id The uuid of the user using Socure
  def idv_doc_auth_socure_webhook_received(
    created_at:,
    customer_user_id:,
    event_type:,
    docv_transaction_token:,
    reference_id:,
    user_id:,
    **extra
  )
    track_event(
      :idv_doc_auth_socure_webhook_received,
      created_at:,
      customer_user_id:,
      docv_transaction_token:,
      event_type:,
      reference_id:,
      user_id:,
      **extra,
    )
  end

  # User submits IdV Social Security number step
  # @identity.idp.previous_event_name IdV: in person proofing ssn submitted
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [Number] previous_ssn_edit_distance The edit distance to the previous submitted SSN
  def idv_doc_auth_ssn_submitted(
    success:,
    errors:,
    step:,
    analytics_id:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    error_details: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    previous_ssn_edit_distance: nil,
    **extra
  )
    track_event(
      'IdV: doc auth ssn submitted',
      success:,
      errors:,
      error_details:,
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      previous_ssn_edit_distance:,
      **extra,
    )
  end

  # User visits IdV Social Security number step
  # @identity.idp.previous_event_name IdV: in person proofing ssn visited
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [Number] previous_ssn_edit_distance The edit distance to the previous submitted SSN
  def idv_doc_auth_ssn_visited(
    step:,
    analytics_id:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    previous_ssn_edit_distance: nil,
    **extra
  )
    track_event(
      'IdV: doc auth ssn visited',
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      previous_ssn_edit_distance:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] submit_attempts Times that user has tried submitting (previously called
  #   "attempts")
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param [String] user_id
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [String] front_image_fingerprint Fingerprint of front image data
  # @param [String] back_image_fingerprint Fingerprint of back image data
  # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # The document capture image uploaded was locally validated during the IDV process
  def idv_doc_auth_submitted_image_upload_form(
    success:,
    errors:,
    remaining_submit_attempts:,
    flow_path:,
    liveness_checking_required:,
    error_details: nil,
    submit_attempts: nil,
    user_id: nil,
    front_image_fingerprint: nil,
    back_image_fingerprint: nil,
    selfie_image_fingerprint: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    **extra
  )
    track_event(
      'IdV: doc auth image upload form submitted',
      success:,
      errors:,
      error_details:,
      submit_attempts:,
      remaining_submit_attempts:,
      user_id:,
      flow_path:,
      front_image_fingerprint:,
      back_image_fingerprint:,
      liveness_checking_required:,
      selfie_image_fingerprint:,
      acuant_sdk_upgrade_ab_test_bucket:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] exception
  # @param [Boolean] billed
  # @param [String] doc_auth_result
  # @param [String] state
  # @param [String] state_id_type
  # @param [Boolean] async
  # @param [Integer] submit_attempts Times that user has tried submitting (previously called
  #   "attempts")
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param [Hash] client_image_metrics
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Float] vendor_request_time_in_ms Time it took to upload images & get a response.
  # @param [String] front_image_fingerprint Fingerprint of front image data
  # @param [String] back_image_fingerprint Fingerprint of back image data
  # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
  # @param [Boolean] attention_with_barcode Whether result was attention with barcode
  # @param [Boolean] doc_type_supported
  # @param [Boolean] doc_auth_success
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # @param [Boolean] liveness_enabled Whether or not the selfie result is included in response
  # @param [String] selfie_status
  # @param [String] vendor
  # @param [String] conversation_id
  # @param [String] request_id RequestId from TrueID
  # @param [String] reference
  # @param [String] transaction_status
  # @param [String] transaction_reason_code
  # @param [String] product_status
  # @param [String] decision_product_status
  # @param [Array] processed_alerts
  # @param [Integer] alert_failure_count
  # @param [Hash] log_alert_results
  # @param [Hash] portrait_match_results
  # @param [Hash] image_metrics
  # @param [Boolean] address_line2_present
  # @param [String] zip_code
  # @param [Boolean] selfie_live Selfie liveness result
  # @param [Boolean] selfie_quality_good Selfie quality result
  # @param [String] workflow LexisNexis TrueID workflow
  # @param [String] birth_year Birth year from document
  # @param [Integer] issue_year Year document was issued
  # @param [Hash] failed_image_fingerprints Hash of document field with an array of failed image
  #   fingerprints for that field.
  # @param [Integer] selfie_attempts number of selfie attempts the user currently has processed
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  #   SDK upgrades
  # @option extra [String] 'DocumentName'
  # @option extra [String] 'DocAuthResult'
  # @option extra [String] 'DocIssuerCode'
  # @option extra [String] 'DocIssuerName'
  # @option extra [String] 'DocIssuerType'
  # @option extra [String] 'DocClassCode'
  # @option extra [String] 'DocClass'
  # @option extra [String] 'DocClassName'
  # @option extra [Boolean] 'DocIsGeneric'
  # @option extra [String] 'DocIssue'
  # @option extra [String] 'DocIssueType'
  # @option extra [String] 'ClassificationMode'
  # @option extra [Boolean] 'OrientationChanged'
  # @option extra [Boolean] 'PresentationChanged'
  # The document capture image was uploaded to vendor during the IDV process
  def idv_doc_auth_submitted_image_upload_vendor(
    success:,
    errors:,
    exception:,
    state:,
    state_id_type:,
    async:,
    submit_attempts:,
    remaining_submit_attempts:,
    client_image_metrics:,
    flow_path:,
    liveness_checking_required:,
    issue_year:,
    failed_image_fingerprints: nil,
    billed: nil,
    doc_auth_result: nil,
    vendor_request_time_in_ms: nil,
    front_image_fingerprint: nil,
    back_image_fingerprint: nil,
    selfie_image_fingerprint: nil,
    attention_with_barcode: nil,
    doc_type_supported: nil,
    doc_auth_success: nil,
    selfie_status: nil,
    vendor: nil,
    conversation_id: nil,
    request_id: nil,
    reference: nil,
    transaction_status: nil,
    transaction_reason_code: nil,
    product_status: nil,
    decision_product_status: nil,
    processed_alerts: nil,
    alert_failure_count: nil,
    log_alert_results: nil,
    portrait_match_results: nil,
    image_metrics: nil,
    address_line2_present: nil,
    zip_code: nil,
    selfie_live: nil,
    selfie_quality_good: nil,
    workflow: nil,
    birth_year: nil,
    selfie_attempts: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    liveness_enabled: nil,
    **extra
  )
    track_event(
      'IdV: doc auth image upload vendor submitted',
      success:,
      errors:,
      exception:,
      billed:,
      doc_auth_result:,
      state:,
      state_id_type:,
      async:,
      submit_attempts: submit_attempts,
      remaining_submit_attempts: remaining_submit_attempts,
      client_image_metrics:,
      flow_path:,
      vendor_request_time_in_ms:,
      front_image_fingerprint:,
      back_image_fingerprint:,
      selfie_image_fingerprint:,
      attention_with_barcode:,
      doc_type_supported:,
      doc_auth_success:,
      selfie_status:,
      vendor:,
      conversation_id:,
      request_id:,
      reference:,
      transaction_status:,
      transaction_reason_code:,
      product_status:,
      decision_product_status:,
      processed_alerts:,
      alert_failure_count:,
      log_alert_results:,
      portrait_match_results:,
      image_metrics:,
      address_line2_present:,
      liveness_checking_required:,
      zip_code:,
      selfie_live:,
      selfie_quality_good:,
      workflow:,
      birth_year:,
      issue_year:,
      failed_image_fingerprints:,
      selfie_attempts:,
      acuant_sdk_upgrade_ab_test_bucket:,
      liveness_enabled:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] user_id
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # @param ["present","missing"] id_issued_status Status of state_id_issued field presence
  # @param ["present","missing"] id_expiration_status Status of state_id_expiration field presence
  # @param [Boolean] attention_with_barcode Whether result was attention with barcode
  # @param [Integer] submit_attempts Times that user has tried submitting
  # @param [String] front_image_fingerprint Fingerprint of front image data
  # @param [String] back_image_fingerprint Fingerprint of back image data
  # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
  # @param [Hash] classification_info document image side information, issuing country and type etc
  # The PII that came back from the document capture vendor was validated
  def idv_doc_auth_submitted_pii_validation(
    success:,
    errors:,
    remaining_submit_attempts:,
    flow_path:,
    liveness_checking_required:,
    attention_with_barcode:,
    id_issued_status:,
    id_expiration_status:,
    submit_attempts:,
    error_details: nil,
    user_id: nil,
    front_image_fingerprint: nil,
    back_image_fingerprint: nil,
    selfie_image_fingerprint: nil,
    classification_info: {},
    **extra
  )
    track_event(
      'IdV: doc auth image upload vendor pii validation',
      success:,
      errors:,
      error_details:,
      user_id:,
      attention_with_barcode:,
      id_issued_status:,
      id_expiration_status:,
      submit_attempts:,
      remaining_submit_attempts:,
      flow_path:,
      front_image_fingerprint:,
      back_image_fingerprint:,
      selfie_image_fingerprint:,
      classification_info:,
      liveness_checking_required:,
      **extra,
    )
  end

  # User visits IdV verify step waiting on a resolution proofing job result
  # @identity.idp.previous_event_name IdV: doc auth verify visited
  def idv_doc_auth_verify_polling_wait_visited(**extra)
    track_event(:idv_doc_auth_verify_polling_wait_visited, **extra)
  end

  # rubocop:disable Layout/LineLength
  # @param ab_tests [Hash] Object that holds A/B test data (legacy A/B tests may include attributes outside the scope of this object)
  # @param acuant_sdk_upgrade_ab_test_bucket [String] A/B test bucket for Acuant document capture SDK upgrades
  # @param address_edited [Boolean] Whether the user edited their address before submitting the "Verify your information" step
  # @param address_line2_present [Boolean] Whether the user's address includes a second address line
  # @param analytics_id [String] "Doc Auth" for remote unsupervised, "In Person Proofing" for IPP
  # @param errors [Hash] Details about vendor-specific errors encountered during the stages of the identity resolution process
  # @param flow_path [String] "hybrid" for hybrid handoff, "standard" otherwise
  # @param lexisnexis_instant_verify_workflow_ab_test_bucket [String] A/B test bucket for Lexis Nexis InstantVerify workflow testing
  # @param opted_in_to_in_person_proofing [Boolean] Whether this user explicitly opted into in-person proofing
  # @param proofing_results [Hash]
  # @option proofing_results [String,nil] exception If an exception occurred during any phase of proofing its message is provided here
  # @option proofing_results [Boolean] timed_out true if any vendor API calls timed out during proofing
  # @option proofing_results [String] threatmetrix_review_status Result of Threatmetrix assessment, either "review", "reject", or "pass"
  # @option proofing_results [Hash] context Full context of the proofing process
  # @option proofing_results [String] context.device_profiling_adjudication_reason Reason code describing how we arrived at the device profiling result
  # @option proofing_results [String] context.resolution_adjudication_reason Reason code describing how we arrived at the identity resolution result
  # @option proofing_results [Boolean] context.should_proof_state_id Whether we need to verify the user's PII with AAMVA. False if the user is using a document from a non-AAMVA jurisdiction
  # @option proofing_results [Hash] context.stages Object holding details about each stage of the proofing process
  # @option proofing_results [Hash] context.stages.resolution Object holding details about the call made to the identity resolution vendor
  # @option proofing_results [Boolean] context.stages.resolution.success Whether identity resolution proofing was successful
  # @option proofing_results [Hash] context.stages.resolution.errors Object describing errors encountered during identity resolution
  # @option proofing_results [String,nil] context.stages.resolution.exception If an exception occured during identity resolution its message is provided here
  # @option proofing_results [Boolean] context.stages.resolution.timed_out Whether the identity resolution API request timed out
  # @option proofing_results [String] context.stages.resolution.transaction_id A unique id for the underlying vendor request
  # @option proofing_results [Boolean] context.stages.resolution.can_pass_with_additional_verification Whether the PII could be verified if another vendor verified certain attributes
  # @option proofing_results [Array<String>] context.stages.resolution.attributes_requiring_additional_verification Attributes that need to be verified by another vendor
  # @option proofing_results [String] context.stages.resolution.vendor_name Vendor used (e.g. lexisnexis:instant_verify)
  # @option proofing_results [String] context.stages.resolution.vendor_workflow ID of workflow or configuration the vendor used for this transaction
  # @option proofing_results [Boolean] context.stages.residential_address.success Whether the residential address passed proofing
  # @option proofing_results [Hash] context.stages.residential_address.errors Object holding error details returned by the residential address proofing vendor.
  # @option proofing_results [String,nil] context.stages.residential_address.exception If an exception occured during residential address verification its message is provided here
  # @option proofing_results [Boolean] context.stages.residential_address.timed_out True if the request to the residential address proofing vendor timed out
  # @option proofing_results [String] context.stages.residential_address.transaction_id Vendor-specific transaction ID for the request made to the residential address proofing vendor
  # @option proofing_results [Boolean] context.stages.residential_address.can_pass_with_additional_verification Whether, if residential address proofing failed, it could pass with additional proofing from another vendor
  # @option proofing_results [Array<String>,nil] context.stages.residential_address.attributes_requiring_additional_verification List of PII attributes that require additional verification for residential address proofing to pass
  # @option proofing_results [String] context.stages.residential_address.vendor_name Vendor used for residential address proofing
  # @option proofing_results [String] context.stages.residential_address.vendor_workflow Vendor-specific workflow or configuration ID associated with the request made.
  # @option proofing_results [Hash] context.stages.state_id Object holding details about the call made to the state ID proofing vendor
  # @option proofing_results [Boolean] context.stages.state_id.success Whether the PII associated with the user's state ID document passed proofing
  # @option proofing_results [Hash] context.stages.state_id.errors Object describing errors encountered while proofing the user's state ID PII
  # @option proofing_results [String,nil] context.stages.state_id.exception If an exception occured during state ID PII verification its message is provided here
  # @option proofing_results [Boolean] context.stages.state_id.mva_exception For AAMVA, whether the exception that occurred was due to an error on the state MVA side
  # @option proofing_results [Hash<String,Numeric>] context.stages.state_id.requested_attributes An object whose keys are field names and values are "1" representing PII attributes sent to the state ID proofing vendor for verification.
  # @option proofing_results [Boolean] context.stages.state_id.timed_out Whether the request to the state ID verification vendor timed out
  # @option proofing_results [String] context.stages.state_id.transaction_id Vendor-specific transaction ID for the request made to the state id proofing vendor
  # @option proofing_results [String] context.stages.state_id.vendor_name Name of the vendor used for state ID PII verification. If the ID was not from a supported jurisdiction, it will be "UnsupportedJurisdiction". It MAY also be "UnsupportedJurisdiction" if state ID verification was not needed because other vendor calls did not succeed.
  # @option proofing_results [String] context.stages.state_id.state The state that was listed as the user's address on their state ID. Note that this may differ from state_id_jurisdiction.
  # @option proofing_results [String] context.stages.state_id.state_id_jurisdiction The state that issued the drivers license or ID card being used for proofing.
  # @option proofing_results [String] context.stages.state_id.state_id_number A string describing the _format_ of the state ID number provided.
  # @option proofing_results [Hash] context.stages.threatmetrix Object holding details about the call made to the device profiling vendor
  # @option proofing_results [String] context.stages.threatmetrix.client Identifier string indicating which client was used.
  # @option proofing_results [Boolean] context.stages.threatmetrix.success Whether the request to the vendor succeeded.
  # @option proofing_results [Hash] context.stages.threatmetrix.errors Hash describing errors encountered when making the request.
  # @option proofing_results [String,nil] context.stages.threatmetrix.exception If an exception was encountered making the request to the vendor, its message is provided here.
  # @option proofing_results [Boolean] context.stages.threatmetrix.timed_out Whether the request to the vendor timed out.
  # @option proofing_results [String] context.stages.threatmetrix.transaction_id Vendor-specific transaction ID for the request.
  # @option proofing_results [String] context.stages.threatmetrix.session_id Session ID associated with the response.
  # @option proofing_results [String] context.stages.threatmetrix.account_lex_id LexID associated with the response.
  # @option proofing_results [Hash] context.stages.threatmetrix.response_body JSON body of the response returned from the vendor. PII has been redacted.
  # @option proofing_results [String] context.stages.threatmetrix.review_status One of "pass", "review", "reject".
  # @param skip_hybrid_handoff [Boolean] Whether the user should skip hybrid handoff (i.e. because they are already on a mobile device)
  # @param ssn_is_unique [Boolean] Whether another Profile existed with the same SSN at the time the profile associated with the current IdV session was minted.
  # @param step [String] Always "verify" (leftover from flow state machine days)
  # @param success [Boolean] Whether identity resolution succeeded overall
  # @param previous_ssn_edit_distance [Number] The edit distance to the previous submitted SSN
  def idv_doc_auth_verify_proofing_results(
    ab_tests: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    address_edited: nil,
    address_line2_present: nil,
    analytics_id: nil,
    errors: nil,
    flow_path: nil,
    lexisnexis_instant_verify_workflow_ab_test_bucket: nil,
    opted_in_to_in_person_proofing: nil,
    proofing_results: nil,
    skip_hybrid_handoff: nil,
    ssn_is_unique: nil,
    step: nil,
    success: nil,
    previous_ssn_edit_distance: nil,
    **extra
  )
    track_event(
      'IdV: doc auth verify proofing results',
      ab_tests:,
      acuant_sdk_upgrade_ab_test_bucket:,
      address_edited:,
      address_line2_present:,
      analytics_id:,
      errors:,
      flow_path:,
      lexisnexis_instant_verify_workflow_ab_test_bucket:,
      opted_in_to_in_person_proofing:,
      proofing_results:,
      skip_hybrid_handoff:,
      ssn_is_unique:,
      step:,
      success:,
      previous_ssn_edit_distance:,
      **extra,
    )
  end
  # rubocop:enable Layout/LineLength

  # User submits IdV verify step
  # @identity.idp.previous_event_name IdV: in person proofing verify submitted
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_verify_submitted(
    step:,
    analytics_id:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth verify submitted',
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # User visits IdV verify step
  # @identity.idp.previous_event_name IdV: in person proofing verify visited
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_verify_visited(
    step:,
    analytics_id:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth verify visited',
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      flow_path:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # @param [String] step_name
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # The user was sent to a warning page during the IDV flow
  def idv_doc_auth_warning_visited(step_name:, remaining_submit_attempts:, **extra)
    track_event(
      'IdV: doc auth warning visited',
      step_name: step_name,
      remaining_submit_attempts: remaining_submit_attempts,
      **extra,
    )
  end

  # User submits IdV welcome screen
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_welcome_submitted(
    step:,
    analytics_id:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth welcome submitted',
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      **extra,
    )
  end

  # User visits IdV welcome screen
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_doc_auth_welcome_visited(
    step:,
    analytics_id:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: doc auth welcome visited',
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # User submitted IDV password confirm page
  # @param [Boolean] success
  # @param [Boolean] fraud_review_pending
  # @param [Boolean] fraud_rejection
  # @param [String,nil] fraud_pending_reason The reason this profile is eligible for fraud review
  # @param [Boolean] gpo_verification_pending
  # @param [Boolean] in_person_verification_pending
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String, nil] deactivation_reason Reason user's profile was deactivated, if any.
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Integer,nil] proofing_workflow_time_in_seconds The time since starting proofing
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @identity.idp.previous_event_name  IdV: review info visited
  def idv_enter_password_submitted(
    success:,
    fraud_review_pending:,
    fraud_rejection:,
    fraud_pending_reason:,
    gpo_verification_pending:,
    in_person_verification_pending:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    deactivation_reason: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    proofing_workflow_time_in_seconds: nil,
    **extra
  )
    track_event(
      :idv_enter_password_submitted,
      success:,
      deactivation_reason:,
      fraud_review_pending:,
      fraud_pending_reason:,
      gpo_verification_pending:,
      in_person_verification_pending:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      opted_in_to_in_person_proofing:,
      fraud_rejection:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      proofing_workflow_time_in_seconds:,
      **extra,
    )
  end

  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String] address_verification_method The method (phone or gpo) being
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  #        used to verify the user's identity
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # User visited IDV password confirm page
  # @identity.idp.previous_event_name  IdV: review info visited
  def idv_enter_password_visited(
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    proofing_components: nil,
    address_verification_method: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      :idv_enter_password_visited,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      address_verification_method:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [String, nil] deactivation_reason Reason user's profile was deactivated, if any.
  # @param [Boolean] fraud_review_pending Profile is under review for fraud
  # @param [Boolean] fraud_rejection Profile is rejected due to fraud
  # @param [String,nil] fraud_pending_reason The reason this profile is eligible for fraud review
  # @param [Boolean] gpo_verification_pending Profile is awaiting gpo verification
  # @param [Boolean] in_person_verification_pending Profile is awaiting in person verification
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
  # @param [Integer,nil] proofing_workflow_time_in_seconds The time since starting proofing
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @see Reporting::IdentityVerificationReport#query This event is used by the identity verification
  #       report. Changes here should be reflected there.
  # Tracks the last step of IDV, indicates the user successfully proofed
  def idv_final(
    success:,
    fraud_review_pending:,
    fraud_rejection:,
    fraud_pending_reason:,
    gpo_verification_pending:,
    in_person_verification_pending:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    deactivation_reason: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    profile_history: nil,
    proofing_workflow_time_in_seconds: nil,
    **extra
  )
    track_event(
      'IdV: final resolution',
      success:,
      fraud_review_pending:,
      fraud_rejection:,
      fraud_pending_reason:,
      gpo_verification_pending:,
      in_person_verification_pending:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      deactivation_reason:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      profile_history:,
      proofing_workflow_time_in_seconds:,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # User visited forgot password page
  def idv_forgot_password(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: forgot password visited',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # User confirmed forgot password
  def idv_forgot_password_confirmed(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: forgot password confirmed',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [String] acuantCaptureMode
  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [Boolean] assessment
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # @param [String] documentType
  # @param [Integer] dpi  dots per inch of image
  # @param [Integer] failedImageResubmission
  # @param [String] fingerprint fingerprint of the image added
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Integer] glare
  # @param [Integer] glareScoreThreshold
  # @param [Integer] height height of image added in pixels
  # @param [Boolean] isAssessedAsBlurry
  # @param [Boolean] isAssessedAsGlare
  # @param [Boolean] isAssessedAsUnsupported
  # @param [String] mimeType MIME type of image added
  # @param [Integer] moire
  # @param [Integer] sharpness
  # @param [Integer] sharpnessScoreThreshold
  # @param [Integer] size size of image added in bytes
  # @param [String] source
  # @param [Boolean] use_alternate_sdk
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [Integer] width width of image added in pixels
  # Front image was added in document capture
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_front_image_added(
    acuantCaptureMode:,
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    assessment:,
    captureAttempts:,
    documentType:,
    dpi:,
    failedImageResubmission:,
    fingerprint:,
    flow_path:,
    glare:,
    glareScoreThreshold:,
    height:,
    isAssessedAsBlurry:,
    isAssessedAsGlare:,
    isAssessedAsUnsupported:,
    mimeType:,
    moire:,
    sharpness:,
    sharpnessScoreThreshold:,
    size:,
    source:,
    use_alternate_sdk:,
    liveness_checking_required:,
    width:,
    **extra
  )
    track_event(
      'Frontend: IdV: front image added',
      acuantCaptureMode: acuantCaptureMode,
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      assessment: assessment,
      captureAttempts: captureAttempts,
      documentType: documentType,
      dpi: dpi,
      failedImageResubmission: failedImageResubmission,
      fingerprint: fingerprint,
      flow_path: flow_path,
      glare: glare,
      glareScoreThreshold: glareScoreThreshold,
      height: height,
      isAssessedAsBlurry: isAssessedAsBlurry,
      isAssessedAsGlare: isAssessedAsGlare,
      isAssessedAsUnsupported: isAssessedAsUnsupported,
      mimeType: mimeType,
      moire: moire,
      sharpness: sharpness,
      sharpnessScoreThreshold: sharpnessScoreThreshold,
      size: size,
      source: source,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
      width: width,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] isDrop
  # @param [String] click_source
  # @param [String] use_alternate_sdk
  # @param [Number] captureAttempts count of image capturing attempts
  # @param [Boolean] liveness_checking_required
  def idv_front_image_clicked(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    isDrop:,
    click_source:,
    use_alternate_sdk:,
    captureAttempts:,
    liveness_checking_required: nil,
    **extra
  )
    track_event(
      'Frontend: IdV: front image clicked',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      isDrop: isDrop,
      click_source: click_source,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
      captureAttempts: captureAttempts,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # @param [DateTime] enqueued_at When letter was enqueued
  # @param [Boolean] resend User requested a second (or more) letter
  # @param [DateTime] first_letter_requested_at When the profile became gpo_pending
  # @param [Integer] hours_since_first_letter Difference between first_letter_requested_at
  #                  and now in hours
  # @param [Integer] phone_step_attempts Number of attempts at phone step before requesting letter
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # GPO letter was enqueued and the time at which it was enqueued
  def idv_gpo_address_letter_enqueued(
    enqueued_at:,
    resend:,
    first_letter_requested_at:,
    hours_since_first_letter:,
    phone_step_attempts:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: USPS address letter enqueued',
      enqueued_at:,
      resend:,
      first_letter_requested_at:,
      hours_since_first_letter:,
      phone_step_attempts:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [Boolean] resend
  # @param [DateTime] first_letter_requested_at When the profile became gpo_pending
  # @param [Integer] hours_since_first_letter Difference between first_letter_requested_at
  #                  and now in hours
  # @param [Integer] phone_step_attempts Number of attempts at phone step before requesting letter
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # GPO letter was requested
  def idv_gpo_address_letter_requested(
    resend:,
    first_letter_requested_at:,
    hours_since_first_letter:,
    phone_step_attempts:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: USPS address letter requested',
      resend:,
      first_letter_requested_at:,
      hours_since_first_letter:,
      phone_step_attempts:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # The user visited the gpo confirm cancellation screen from RequestLetter
  def idv_gpo_confirm_start_over_before_letter_visited(**extra)
    track_event(:idv_gpo_confirm_start_over_before_letter_visited, **extra)
  end

  # The user visited the gpo confirm cancellation screen
  def idv_gpo_confirm_start_over_visited(**extra)
    track_event('IdV: gpo confirm start over visited', **extra)
  end

  # The user ran out of time to complete their address verification by mail.
  # @param [String] user_id UUID of the user who expired
  # @param [Boolean] user_has_active_profile Whether the user currently has an active profile
  # @param [Integer] letters_sent Total # of GPO letters sent for this profile
  # @param [Time] gpo_verification_pending_at Date/time when profile originally entered GPO flow
  def idv_gpo_expired(
    user_id:,
    user_has_active_profile:,
    letters_sent:,
    gpo_verification_pending_at:,
    **extra
  )
    track_event(
      :idv_gpo_expired,
      user_id: user_id,
      user_has_active_profile: user_has_active_profile,
      letters_sent: letters_sent,
      gpo_verification_pending_at: gpo_verification_pending_at,
      **extra,
    )
  end

  # A GPO reminder email was sent to the user
  # @param [String] user_id UUID of user who we sent a reminder to
  def idv_gpo_reminder_email_sent(user_id:, **extra)
    track_event('IdV: gpo reminder email sent', user_id: user_id, **extra)
  end

  # @param [String] field back or front
  # @param [String] acuantCaptureMode
  # @param [String] error
  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] use_alternate_sdk
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_image_capture_failed(
    field:,
    acuantCaptureMode:,
    error:,
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    use_alternate_sdk:,
    **extra
  )
    track_event(
      'Frontend: IdV: Image capture failed',
      field: field,
      acuantCaptureMode: acuantCaptureMode,
      error: error,
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      use_alternate_sdk: use_alternate_sdk,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User chooses to try In Person, e.g. from a doc_auth timeout error page
  # @param [Integer] remaining_submit_attempts The number of remaining attempts to submit
  # @param [Boolean] skip_hybrid_handoff Whether the user skipped the hybrid handoff A/B test
  # @param [Boolean] opted_in_to_in_person_proofing Whether the user opted into in-person proofing
  def idv_in_person_direct_start(
    remaining_submit_attempts:,
    skip_hybrid_handoff: nil,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      :idv_in_person_direct_start,
      remaining_submit_attempts:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # Tracks emails that are initiated during InPerson::EmailReminderJob
  # @param [String] email_type early or late
  # @param [String] enrollment_id
  def idv_in_person_email_reminder_job_email_initiated(
    email_type:,
    enrollment_id:,
    **extra
  )
    track_event(
      'InPerson::EmailReminderJob: Reminder email initiated',
      email_type: email_type,
      enrollment_id: enrollment_id,
      **extra,
    )
  end

  # Tracks exceptions that are raised when running InPerson::EmailReminderJob
  # @param [String] enrollment_id
  # @param [String] exception_class
  # @param [String] exception_message
  def idv_in_person_email_reminder_job_exception(
    enrollment_id:,
    exception_class: nil,
    exception_message: nil,
    **extra
  )
    track_event(
      'InPerson::EmailReminderJob: Exception raised when attempting to send reminder email',
      enrollment_id: enrollment_id,
      exception_class: exception_class,
      exception_message: exception_message,
      **extra,
    )
  end

  # @param [String] selected_location Selected in-person location
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user submitted the in person proofing location step
  def idv_in_person_location_submitted(
    selected_location:,
    flow_path:,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing location submitted',
      selected_location: selected_location,
      flow_path: flow_path,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user visited the in person proofing location step
  def idv_in_person_location_visited(flow_path:, opted_in_to_in_person_proofing:, **extra)
    track_event(
      'IdV: in person proofing location visited',
      flow_path: flow_path,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      **extra,
    )
  end

  # Tracks if request to get USPS in-person proofing locations fails
  # @param [Integer] api_status_code HTTP status code for API response
  # @param [String] exception_class
  # @param [String] exception_message
  # @param [Boolean] response_body_present
  # @param [Hash] response_body
  # @param [Integer] response_status_code
  def idv_in_person_locations_request_failure(
    api_status_code:,
    exception_class:,
    exception_message:,
    response_body_present:,
    response_body:,
    response_status_code:,
    **extra
  )
    track_event(
      'Request USPS IPP locations: request failed',
      api_status_code:,
      exception_class:,
      exception_message:,
      response_body_present:,
      response_body:,
      response_status_code:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Integer] result_total
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] exception_class
  # @param [String] exception_message
  # @param [Integer] response_status_code
  # User submitted a search on the location search page and response received
  def idv_in_person_locations_searched(
    success:,
    result_total: 0,
    errors: nil,
    exception_class: nil,
    exception_message: nil,
    response_status_code: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing location search submitted',
      success: success,
      result_total: result_total,
      errors: errors,
      exception_class: exception_class,
      exception_message: exception_message,
      response_status_code: response_status_code,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user submitted the in person proofing prepare step
  def idv_in_person_prepare_submitted(flow_path:, opted_in_to_in_person_proofing:, **extra)
    track_event(
      'IdV: in person proofing prepare submitted',
      flow_path: flow_path,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user visited the in person proofing prepare step
  def idv_in_person_prepare_visited(flow_path:, opted_in_to_in_person_proofing:, **extra)
    track_event(
      'IdV: in person proofing prepare visited',
      flow_path: flow_path,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  #   address page visited
  def idv_in_person_proofing_address_visited(
    flow_path:,
    step:,
    analytics_id:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing address visited',
      flow_path:,
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      **extra,
    )
  end

  # A job to check USPS notifications about in-person enrollment status updates has completed
  # @param [Integer] fetched_items items fetched
  # @param [Integer] processed_items items fetched and processed
  # @param [Integer] deleted_items items fetched, processed, and then deleted from the queue
  # @param [Integer] valid_items items that could be successfully used to update a record
  # @param [Integer] invalid_items items that couldn't be used to update a record
  # @param [Integer] incomplete_items fetched items not processed nor deleted from the queue
  # @param [Integer] deletion_failed_items processed items that we failed to delete
  def idv_in_person_proofing_enrollments_ready_for_status_check_job_completed(
    fetched_items:,
    processed_items:,
    deleted_items:,
    valid_items:,
    invalid_items:,
    incomplete_items:,
    deletion_failed_items:,
    **extra
  )
    track_event(
      'InPersonEnrollmentsReadyForStatusCheckJob: Job completed',
      fetched_items:,
      processed_items:,
      deleted_items:,
      valid_items:,
      invalid_items:,
      incomplete_items:,
      deletion_failed_items:,
      **extra,
    )
  end

  # A job to check USPS notifications about in-person enrollment status updates
  # has encountered an error
  # @param [String] exception_class
  # @param [String] exception_message
  def idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error(
    exception_class:,
    exception_message:,
    **extra
  )
    track_event(
      'InPersonEnrollmentsReadyForStatusCheckJob: Ingestion error',
      exception_class:,
      exception_message:,
      **extra,
    )
  end

  # A job to check USPS notifications about in-person enrollment status updates has started
  def idv_in_person_proofing_enrollments_ready_for_status_check_job_started(**extra)
    track_event(
      'InPersonEnrollmentsReadyForStatusCheckJob: Job started',
      **extra,
    )
  end

  # @param [String] nontransliterable_characters
  # Nontransliterable characters submitted by user
  def idv_in_person_proofing_nontransliterable_characters_submitted(
    nontransliterable_characters:,
    **extra
  )
    track_event(
      'IdV: in person proofing characters submitted could not be transliterated',
      nontransliterable_characters: nontransliterable_characters,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] step Current IdV step
  # @param [String] analytics_id Current IdV flow identifier
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [String] current_address_zip_code ZIP code of given address
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  def idv_in_person_proofing_residential_address_submitted(
    success:,
    errors:,
    flow_path:,
    step:,
    analytics_id:,
    current_address_zip_code:,
    opted_in_to_in_person_proofing: nil,
    error_details: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing residential address submitted',
      success:,
      errors:,
      flow_path:,
      step:,
      analytics_id:,
      current_address_zip_code:,
      opted_in_to_in_person_proofing:,
      error_details:,
      skip_hybrid_handoff:,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [String] birth_year Birth year from document
  # @param [String] document_zip_code ZIP code from document
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # User submitted state id
  def idv_in_person_proofing_state_id_submitted(
    success:,
    errors:,
    flow_path:,
    step:,
    analytics_id:,
    birth_year:,
    document_zip_code:,
    skip_hybrid_handoff: nil,
    error_details: nil,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing state_id submitted',
      flow_path:,
      step:,
      analytics_id:,
      success:,
      errors:,
      error_details:,
      birth_year:,
      document_zip_code:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing:,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # State id page visited
  def idv_in_person_proofing_state_id_visited(
    flow_path: nil,
    step: nil,
    analytics_id: nil,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing state_id visited',
      flow_path:,
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      **extra,
    )
  end

  # The user clicked the sp link on the "ready to verify" page
  def idv_in_person_ready_to_verify_sp_link_clicked(**extra)
    track_event(
      'IdV: user clicked sp link on ready to verify page',
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user visited the "ready to verify" page for the in person proofing flow
  def idv_in_person_ready_to_verify_visit(
    opted_in_to_in_person_proofing: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: in person ready to verify visited',
      opted_in_to_in_person_proofing:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # The user clicked the what to bring link on the "ready to verify" page
  def idv_in_person_ready_to_verify_what_to_bring_link_clicked(**extra)
    track_event(
      'IdV: user clicked what to bring link on ready to verify page',
      **extra,
    )
  end

  # Track sms notification attempt
  # @param [boolean] success sms notification successful or not
  # @param [String] enrollment_code enrollment_code
  # @param [String] enrollment_id enrollment_id
  # @param [Hash] telephony_response Response from Telephony gem
  # @param [Hash] extra extra information
  def idv_in_person_send_proofing_notification_attempted(
    success:,
    enrollment_code:,
    enrollment_id:,
    telephony_response:,
    **extra
  )
    track_event(
      'SendProofingNotificationJob: in person notification SMS send attempted',
      success: success,
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      telephony_response: telephony_response,
      **extra,
    )
  end

  # Track sms notification job completion
  # @param [String] enrollment_code enrollment_code
  # @param [String] enrollment_id enrollment_id
  # @param [Hash] extra extra information
  def idv_in_person_send_proofing_notification_job_completed(
    enrollment_code:,
    enrollment_id:,
    **extra
  )
    track_event(
      'SendProofingNotificationJob: job completed',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      **extra,
    )
  end

  # Tracks exceptions that are raised when running InPerson::SendProofingNotificationJob
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [String] exception_class
  # @param [String] exception_message
  # @param [Hash] extra extra information
  def idv_in_person_send_proofing_notification_job_exception(
    enrollment_code:,
    enrollment_id:,
    exception_class: nil,
    exception_message: nil,
    **extra
  )
    track_event(
      'SendProofingNotificationJob: exception raised',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      exception_class: exception_class,
      exception_message: exception_message,
      **extra,
    )
  end

  # Track sms notification job skipped
  # @param [String] enrollment_code enrollment_code
  # @param [String] enrollment_id enrollment_id
  # @param [Hash] extra extra information
  def idv_in_person_send_proofing_notification_job_skipped(
    enrollment_code:,
    enrollment_id:,
    **extra
  )
    track_event(
      'SendProofingNotificationJob: job skipped',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      **extra,
    )
  end

  # Track sms notification job started
  # @param [String] enrollment_code enrollment_code
  # @param [String] enrollment_id enrollment_id
  # @param [Hash] extra extra information
  def idv_in_person_send_proofing_notification_job_started(
    enrollment_code:,
    enrollment_id:,
    **extra
  )
    track_event(
      'SendProofingNotificationJob: job started',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # The user submitted the in person proofing switch_back step
  def idv_in_person_switch_back_submitted(flow_path:, **extra)
    track_event('IdV: in person proofing switch_back submitted', flow_path: flow_path, **extra)
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # The user visited the in person proofing switch_back step
  def idv_in_person_switch_back_visited(flow_path:, **extra)
    track_event('IdV: in person proofing switch_back visited', flow_path: flow_path, **extra)
  end

  # An email from USPS with an enrollment code has been received, indicating
  # the enrollment is approved or failed. A check is required to get the status
  # it is not included in the email.
  # @param [boolean] multi_part If the email is marked as multi_part
  # @param [string] part_found Records if the enrollment code was found in text_part or html_part
  def idv_in_person_usps_proofing_enrollment_code_email_received(
    multi_part: nil,
    part_found: nil,
    **extra
  )
    track_event(
      'IdV: in person usps proofing enrollment code email received',
      multi_part: multi_part,
      part_found: part_found,
      **extra,
    )
  end

  # GetUspsProofingResultsJob has completed. Includes counts of various outcomes encountered
  # @param [Float] duration_seconds number of minutes the job was running
  # @param [Integer] enrollments_checked number of enrollments eligible for status check
  # @param [Integer] enrollments_errored number of enrollments for which we encountered an error
  # @param [Integer] enrollments_expired number of enrollments which expired
  # @param [Integer] enrollments_failed number of enrollments which failed identity proofing
  # @param [Integer] enrollments_in_progress number of enrollments which did not have any change
  # @param [Integer] enrollments_passed number of enrollments which passed identity proofing
  # @param [Integer] enrollments_network_error
  # @param [Integer] enrollments_cancelled
  # @param [Float] percent_enrollments_errored
  # @param [Float] percent_enrollments_network_error
  # @param [String] job_name
  def idv_in_person_usps_proofing_results_job_completed(
    duration_seconds:,
    enrollments_checked:,
    enrollments_errored:,
    enrollments_expired:,
    enrollments_failed:,
    enrollments_in_progress:,
    enrollments_passed:,
    enrollments_network_error:,
    enrollments_cancelled:,
    percent_enrollments_errored:,
    percent_enrollments_network_error:,
    job_name:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Job completed',
      duration_seconds:,
      enrollments_checked:,
      enrollments_errored:,
      enrollments_expired:,
      enrollments_failed:,
      enrollments_in_progress:,
      enrollments_passed:,
      enrollments_network_error:,
      enrollments_cancelled:,
      percent_enrollments_errored:,
      percent_enrollments_network_error:,
      job_name:,
      **extra,
    )
  end

  # Tracks exceptions that are raised when initiating deadline email in GetUspsProofingResultsJob
  # @param [String] enrollment_id
  # @param [String] exception_class
  # @param [String] exception_message
  def idv_in_person_usps_proofing_results_job_deadline_passed_email_exception(
    enrollment_id:,
    exception_class: nil,
    exception_message: nil,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Exception raised when attempting to send deadline passed email',
      enrollment_id: enrollment_id,
      exception_class: exception_class,
      exception_message: exception_message,
      **extra,
    )
  end

  # Tracks deadline email initiated during GetUspsProofingResultsJob
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [Time] timestamp
  # @param [String] service_provider
  # @param [Integer] wait_until
  # @param [String] job_name
  def idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated(
    enrollment_code:,
    enrollment_id:,
    timestamp:,
    service_provider:,
    wait_until:,
    job_name:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: deadline passed email initiated',
      enrollment_code:,
      enrollment_id:,
      timestamp:,
      service_provider:,
      wait_until:,
      job_name:,
      **extra,
    )
  end

  # Tracks emails that are initiated during GetUspsProofingResultsJob
  # @param [String] email_type success, failed or failed fraud
  # @param [String] enrollment_code
  # @param [Time] timestamp
  # @param [String] service_provider
  # @param [Integer] wait_until
  # @param [String] job_name
  def idv_in_person_usps_proofing_results_job_email_initiated(
    email_type:,
    enrollment_code:,
    timestamp:,
    service_provider:,
    wait_until:,
    job_name:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Success or failure email initiated',
      email_type:,
      enrollment_code:,
      timestamp:,
      service_provider:,
      wait_until:,
      job_name:,
      **extra,
    )
  end

  # Tracks incomplete enrollments checked via the USPS API
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [Float] minutes_since_established
  # @param [String] response_message
  def idv_in_person_usps_proofing_results_job_enrollment_incomplete(
    enrollment_code:,
    enrollment_id:,
    minutes_since_established:,
    response_message:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Enrollment incomplete',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      minutes_since_established: minutes_since_established,
      response_message: response_message,
      **extra,
    )
  end

  # Tracks individual enrollments that are updated during GetUspsProofingResultsJob
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [Float] minutes_since_established
  # @param [Float] minutes_since_last_status_check
  # @param [Float] minutes_since_last_status_check_completed
  # @param [Float] minutes_since_last_status_update
  # @param [Float] minutes_to_completion
  # @param [Boolean] fraud_suspected
  # @param [String] primary_id_type
  # @param [String] secondary_id_type
  # @param [String] failure_reason
  # @param [String] transaction_end_date_time
  # @param [String] transaction_start_date_time
  # @param [String] status
  # @param [String] assurance_level
  # @param [String] proofing_post_office
  # @param [String] proofing_city
  # @param [String] proofing_state
  # @param [String] scan_count
  # @param [String] response_message
  # @param [Boolean] passed did this enrollment pass or fail?
  # @param [String] reason why did this enrollment pass or fail?
  # @param [String] tmx_status the tmx_status of the enrollment profile profile
  # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
  # @param [Boolean] response_present
  # @param [String] job_name
  # @param [Boolean] enhanced_ipp
  # @param [String] issuer
  def idv_in_person_usps_proofing_results_job_enrollment_updated(
    enrollment_code:,
    enrollment_id:,
    minutes_since_established:,
    passed:,
    reason:,
    tmx_status:,
    profile_age_in_seconds:,
    minutes_since_last_status_check:,
    minutes_since_last_status_check_completed:,
    minutes_since_last_status_update:,
    minutes_to_completion:,
    response_present:,
    job_name:,
    enhanced_ipp:,
    issuer:,
    fraud_suspected: nil,
    primary_id_type: nil,
    secondary_id_type: nil,
    failure_reason: nil,
    transaction_end_date_time: nil,
    transaction_start_date_time: nil,
    status: nil,
    assurance_level: nil,
    proofing_post_office: nil,
    proofing_city: nil,
    proofing_state: nil,
    scan_count: nil,
    response_message: nil,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Enrollment status updated',
      enrollment_code:,
      enrollment_id:,
      minutes_since_established:,
      passed:,
      reason:,
      tmx_status:,
      profile_age_in_seconds:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      fraud_suspected:,
      primary_id_type:,
      secondary_id_type:,
      failure_reason:,
      transaction_end_date_time:,
      transaction_start_date_time:,
      status:,
      assurance_level:,
      proofing_post_office:,
      proofing_city:,
      proofing_state:,
      scan_count:,
      response_present:,
      response_message:,
      job_name:,
      enhanced_ipp:,
      issuer:,
      **extra,
    )
  end

  # Tracks exceptions that are raised when running GetUspsProofingResultsJob
  # @param [String] reason why was the exception raised?
  # @param [String] enrollment_id
  # @param [String] exception_class
  # @param [String] exception_message
  # @param [String] enrollment_code
  # @param [Float] minutes_since_established
  # @param [Float] minutes_since_last_status_check
  # @param [Float] minutes_since_last_status_check_completed
  # @param [Float] minutes_since_last_status_update
  # @param [Float] minutes_to_completion
  # @param [Boolean] fraud_suspected
  # @param [String] primary_id_type
  # @param [String] secondary_id_type
  # @param [String] failure_reason
  # @param [String] transaction_end_date_time
  # @param [String] transaction_start_date_time
  # @param [String] status
  # @param [String] assurance_level
  # @param [String] proofing_post_office
  # @param [String] proofing_city
  # @param [String] proofing_state
  # @param [String] scan_count
  # @param [Boolean] response_present
  # @param [String] response_message
  # @param [Integer] response_status_code
  # @param [String] job_name
  # @param [String] issuer
  def idv_in_person_usps_proofing_results_job_exception(
    reason:,
    enrollment_id:,
    minutes_since_established:,
    exception_class: nil,
    exception_message: nil,
    enrollment_code: nil,
    minutes_since_last_status_check: nil,
    minutes_since_last_status_check_completed: nil,
    minutes_since_last_status_update: nil,
    minutes_to_completion: nil,
    fraud_suspected: nil,
    primary_id_type: nil,
    secondary_id_type: nil,
    failure_reason: nil,
    transaction_end_date_time: nil,
    transaction_start_date_time: nil,
    status: nil,
    assurance_level: nil,
    proofing_post_office: nil,
    proofing_city: nil,
    proofing_state: nil,
    scan_count: nil,
    response_present: nil,
    response_message: nil,
    response_status_code: nil,
    job_name: nil,
    issuer: nil,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Exception raised',
      reason:,
      enrollment_id:,
      exception_class:,
      exception_message:,
      enrollment_code:,
      minutes_since_established:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      fraud_suspected:,
      primary_id_type:,
      secondary_id_type:,
      failure_reason:,
      transaction_end_date_time:,
      transaction_start_date_time:,
      status:,
      assurance_level:,
      proofing_post_office:,
      proofing_city:,
      proofing_state:,
      scan_count:,
      response_present:,
      response_message:,
      response_status_code:,
      job_name:,
      issuer:,
      **extra,
    )
  end

  # Tracks please call emails that are initiated during GetUspsProofingResultsJob
  # @param [String] enrollment_code
  # @param [String] job_name
  # @param [String] service_provider
  # @param [Time] timestamp
  # @param [Integer] wait_until
  def idv_in_person_usps_proofing_results_job_please_call_email_initiated(
    enrollment_code:,
    job_name:,
    service_provider:,
    timestamp:,
    wait_until:,
    **extra
  )
    track_event(
      :idv_in_person_usps_proofing_results_job_please_call_email_initiated,
      enrollment_code:,
      job_name:,
      service_provider:,
      timestamp:,
      wait_until:,
      **extra,
    )
  end

  # GetUspsProofingResultsJob is beginning. Includes some metadata about what the job will do
  # @param [Integer] enrollments_count number of enrollments eligible for status check
  # @param [Integer] reprocess_delay_minutes minimum delay since last status check
  # @param [String] job_name Name of class which triggered proofing job
  def idv_in_person_usps_proofing_results_job_started(
    enrollments_count:,
    reprocess_delay_minutes:,
    job_name:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Job started',
      enrollments_count:,
      reprocess_delay_minutes:,
      job_name:,
      **extra,
    )
  end

  # Tracks unexpected responses from the USPS API
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [Float] minutes_since_established
  # @param [Float] minutes_since_last_status_check
  # @param [Float] minutes_since_last_status_check_completed
  # @param [Float] minutes_since_last_status_update
  # @param [Float] minutes_to_completion
  # @param [String] issuer
  # @param [String] job_name
  # @param [String] response_message
  # @param [String] reason why was this error unexpected?
  def idv_in_person_usps_proofing_results_job_unexpected_response(
    enrollment_code:,
    enrollment_id:,
    minutes_since_established:,
    minutes_since_last_status_check:,
    minutes_since_last_status_check_completed:,
    minutes_since_last_status_update:,
    minutes_to_completion:,
    issuer:,
    job_name:,
    response_message:,
    reason:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Unexpected response received',
      enrollment_code:,
      enrollment_id:,
      minutes_since_established:,
      response_message:,
      reason:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      issuer:,
      job_name:,
      **extra,
    )
  end

  # A user has been moved to fraud review after completing proofing at the USPS
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [Float] minutes_since_established
  # @param [Float] minutes_since_last_status_check
  # @param [Float] minutes_since_last_status_check_completed
  # @param [Float] minutes_since_last_status_update
  # @param [Float] minutes_to_completion
  # @param [String] issuer
  def idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review(
    enrollment_code:,
    enrollment_id:,
    minutes_since_established:,
    minutes_since_last_status_check:,
    minutes_since_last_status_check_completed:,
    minutes_since_last_status_update:,
    minutes_to_completion:,
    issuer:,
    **extra
  )
    track_event(
      :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
      enrollment_code:,
      enrollment_id:,
      minutes_since_established:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      issuer:,
      **extra,
    )
  end

  # Tracks if USPS in-person proofing enrollment request fails
  # @param [String] context
  # @param [String] reason
  # @param [Integer] enrollment_id
  # @param [String] exception_class
  # @param [String] original_exception_class
  # @param [String] exception_message
  def idv_in_person_usps_request_enroll_exception(
    context:,
    reason:,
    enrollment_id:,
    exception_class:,
    original_exception_class:,
    exception_message:,
    **extra
  )
    track_event(
      'USPS IPPaaS enrollment failed',
      context:,
      enrollment_id:,
      exception_class:,
      original_exception_class:,
      exception_message:,
      reason:,
      **extra,
    )
  end

  # User visits IdV
  # @param [Hash,nil] proofing_components User's proofing components.
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
  def idv_intro_visit(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    profile_history: nil,
    **extra
  )
    track_event(
      'IdV: intro visited',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      profile_history: profile_history,
      **extra,
    )
  end

  # @param [String] enrollment_id
  # A fraud user has been deactivated due to not visting the post office before the deadline
  def idv_ipp_deactivated_for_never_visiting_post_office(
    enrollment_id:,
    **extra
  )
    track_event(
      :idv_ipp_deactivated_for_never_visiting_post_office,
      enrollment_id: enrollment_id,
      **extra,
    )
  end

  # The user visited the "letter enqueued" page shown during the verify by mail flow
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @identity.idp.previous_event_name IdV: come back later visited
  def idv_letter_enqueued_visit(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: letter enqueued visited',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Boolean] isCancelled
  # @param [Boolean] isRateLimited
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_link_sent_capture_doc_polling_complete(
    isCancelled:,
    isRateLimited:,
    **extra
  )
    track_event(
      'Frontend: IdV: Link sent capture doc polling complete',
      isCancelled: isCancelled,
      isRateLimited: isRateLimited,
      **extra,
    )
  end

  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  def idv_link_sent_capture_doc_polling_started(**extra)
    track_event(
      'Frontend: IdV: Link sent capture doc polling started',
      **extra,
    )
  end

  # Tracks when the user visits Mail only warning when vendor_status_sms is set to full_outage
  # @param [String] analytics_id Current IdV flow identifier
  def idv_mail_only_warning_visited(analytics_id:, **extra)
    track_event(
      'IdV: Mail only warning visited',
      analytics_id:,
      **extra,
    )
  end

  # @param [Integer] failed_capture_attempts Number of failed Acuant SDK attempts
  # @param [Integer] failed_submission_attempts Number of failed Acuant doc submissions
  # @param [String] field Image form field
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # The number of acceptable failed attempts (maxFailedAttemptsBeforeNativeCamera) has been met
  # or exceeded, and the system has forced the use of the native camera, rather than Acuant's
  # camera, on mobile devices.
  def idv_native_camera_forced(
    failed_capture_attempts:,
    failed_submission_attempts:,
    field:,
    flow_path:,
    **extra
  )
    track_event(
      'IdV: Native camera forced after failed attempts',
      failed_capture_attempts: failed_capture_attempts,
      failed_submission_attempts: failed_submission_attempts,
      field: field,
      flow_path: flow_path,
      **extra,
    )
  end

  # Tracks when user reaches verify errors due to being rejected due to fraud
  def idv_not_verified_visited(**extra)
    track_event('IdV: Not verified visited', **extra)
  end

  # Tracks if a user clicks the 'acknowledge' checkbox during personal
  # key creation
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [boolean] checked whether the user checked or un-checked
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  #                  the box with this click
  def idv_personal_key_acknowledgment_toggled(
    checked:,
    proofing_components:,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: personal key acknowledgment toggled',
      checked: checked,
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # A user has downloaded their personal key. This event is no longer emitted.
  # @identity.idp.previous_event_name IdV: download personal key
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  def idv_personal_key_downloaded(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: personal key downloaded',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String, nil] deactivation_reason Reason profile was deactivated.
  # @param [Boolean] fraud_review_pending Profile is under review for fraud
  # @param [Boolean] fraud_rejection Profile is rejected due to fraud
  # @param [Boolean] in_person_verification_pending Profile is pending in-person verification
  # @param [String] address_verification_method "phone" or "gpo"
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # User submitted IDV personal key page
  def idv_personal_key_submitted(
    address_verification_method:,
    fraud_review_pending:,
    fraud_rejection:,
    in_person_verification_pending:,
    proofing_components: nil,
    deactivation_reason: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: personal key submitted',
      address_verification_method: address_verification_method,
      in_person_verification_pending: in_person_verification_pending,
      deactivation_reason: deactivation_reason,
      fraud_review_pending: fraud_review_pending,
      fraud_rejection: fraud_rejection,
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String] address_verification_method "phone" or "gpo"
  # @param [Boolean,nil] in_person_verification_pending
  # @param [Boolean] encrypted_profiles_missing True if user's session had no encrypted pii
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # User visited IDV personal key page
  def idv_personal_key_visited(
    opted_in_to_in_person_proofing: nil,
    proofing_components: nil,
    address_verification_method: nil,
    in_person_verification_pending: nil,
    encrypted_profiles_missing: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: personal key visited',
      opted_in_to_in_person_proofing:,
      proofing_components:,
      address_verification_method:,
      in_person_verification_pending:,
      encrypted_profiles_missing:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [String] phone_type Pinpoint phone classification type
  # @param [Array<String>] types Phonelib parsed phone types
  # @param [String] carrier Pinpoint detected phone carrier
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] area_code Area code of phone number
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user submitted their phone on the phone confirmation page
  def idv_phone_confirmation_form_submitted(
    success:,
    otp_delivery_preference:,
    errors:,
    phone_type:,
    types:,
    carrier:,
    country_code:,
    area_code:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    error_details: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation form',
      success:,
      errors:,
      error_details:,
      phone_type:,
      types:,
      carrier:,
      country_code:,
      area_code:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      otp_delivery_preference:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The user was rate limited for submitting too many OTPs during the IDV phone step
  def idv_phone_confirmation_otp_rate_limit_attempts(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'Idv: Phone OTP attempts rate limited',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The user was locked out for hitting the phone OTP rate limit during IDV
  def idv_phone_confirmation_otp_rate_limit_locked_out(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'Idv: Phone OTP rate limited user',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The user was rate limited for requesting too many OTPs during the IDV phone step
  def idv_phone_confirmation_otp_rate_limit_sends(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'Idv: Phone OTP sends rate limited',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] area_code area code of phone number
  # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
  # @param [Hash] telephony_response Response from Telephony gem
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Hash, nil] ab_tests data for ongoing A/B tests
  # The user resent an OTP during the IDV phone step
  def idv_phone_confirmation_otp_resent(
    success:,
    errors:,
    otp_delivery_preference:,
    country_code:,
    area_code:,
    rate_limit_exceeded:,
    telephony_response:,
    phone_fingerprint:,
    error_details: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    ab_tests: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation otp resent',
      success:,
      errors:,
      error_details:,
      otp_delivery_preference:,
      country_code:,
      area_code:,
      rate_limit_exceeded:,
      telephony_response:,
      phone_fingerprint:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      ab_tests:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] area_code area code of phone number
  # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @param [Hash] telephony_response Response from Telephony gem
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [:test, :pinpoint] adapter which adapter the OTP was delivered with
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The user requested an OTP to confirm their phone during the IDV phone step
  def idv_phone_confirmation_otp_sent(
    success:,
    errors:,
    otp_delivery_preference:,
    country_code:,
    area_code:,
    rate_limit_exceeded:,
    phone_fingerprint:,
    telephony_response:,
    adapter:,
    error_details: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation otp sent',
      success:,
      errors:,
      error_details:,
      otp_delivery_preference:,
      country_code:,
      area_code:,
      rate_limit_exceeded:,
      phone_fingerprint:,
      telephony_response:,
      adapter:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Boolean] code_expired if the one-time code expired
  # @param [Boolean] code_matches
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [Integer] second_factor_attempts_count number of attempts to confirm this phone
  # @param [Time, nil] second_factor_locked_at timestamp when the phone was locked out
  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # When a user attempts to confirm possession of a new phone number during the IDV process
  def idv_phone_confirmation_otp_submitted(
    success:,
    errors:,
    code_expired:,
    code_matches:,
    otp_delivery_preference:,
    second_factor_attempts_count:,
    second_factor_locked_at:,
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    error_details: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation otp submitted',
      success:,
      errors:,
      error_details:,
      code_expired:,
      code_matches:,
      otp_delivery_preference:,
      second_factor_attempts_count:,
      second_factor_locked_at:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # When a user visits the page to confirm posession of a new phone number during the IDV process
  def idv_phone_confirmation_otp_visit(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation otp visited',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Hash,nil] proofing_components User's current proofing components
  # @param [Hash] vendor Vendor response payload
  # @param [Boolean] new_phone_added Whether phone number was added to account in submission
  # @param [Boolean] hybrid_handoff_phone_used Whether phone is the same as what was used for hybrid
  #   document capture
  # @param [String] area_code Area code of phone number
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The vendor finished the process of confirming the users phone
  def idv_phone_confirmation_vendor_submitted(
    success:,
    errors:,
    vendor:,
    area_code:,
    country_code:,
    phone_fingerprint:,
    new_phone_added:,
    hybrid_handoff_phone_used:,
    opted_in_to_in_person_proofing: nil,
    error_details: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation vendor',
      success:,
      errors:,
      error_details:,
      vendor:,
      area_code:,
      country_code:,
      phone_fingerprint:,
      new_phone_added:,
      hybrid_handoff_phone_used:,
      opted_in_to_in_person_proofing:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param ['warning','jobfail','failure'] type
  # @param [Time] limiter_expires_at when the rate limit expires
  # @param [Integer] remaining_submit_attempts number of submit attempts remaining
  #                  (previously called "remaining_attempts")
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # When a user gets an error during the phone finder flow of IDV
  def idv_phone_error_visited(
    type:,
    opted_in_to_in_person_proofing: nil,
    skip_hybrid_handoff: nil,
    proofing_components: nil,
    limiter_expires_at: nil,
    remaining_submit_attempts: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: phone error visited',
      type:,
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      proofing_components:,
      limiter_expires_at:,
      remaining_submit_attempts:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
  # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # User visited idv phone of record
  def idv_phone_of_record_visited(
    opted_in_to_in_person_proofing: nil,
    acuant_sdk_upgrade_ab_test_bucket: nil,
    skip_hybrid_handoff: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: phone of record visited',
      opted_in_to_in_person_proofing:,
      skip_hybrid_handoff:,
      acuant_sdk_upgrade_ab_test_bucket:,
      proofing_components:,
      active_profile_idv_level:,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String] step the step the user was on when they clicked use a different phone number
  # User decided to use a different phone number in idv
  def idv_phone_use_different(step:, proofing_components: nil, **extra)
    track_event(
      'IdV: use different phone number',
      step: step,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @identity.idp.previous_event_name IdV: Verify setup errors visited
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
  # Tracks when the user reaches the verify please call page after failing proofing
  def idv_please_call_visited(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    profile_history: nil,
    **extra
  )
    track_event(
      'IdV: Verify please call visited',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      profile_history: profile_history,
      **extra,
    )
  end

  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # The system encountered an error and the proofing results are missing
  def idv_proofing_resolution_result_missing(
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      'IdV: proofing resolution result missing',
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      **extra,
    )
  end

  # GPO "request letter" page visited
  # @identity.idp.previous_event_name IdV: USPS address visited
  def idv_request_letter_visited(
    **extra
  )
    track_event(
      'IdV: request letter visited',
      **extra,
    )
  end

  # GPO "resend letter" page visited
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @identity.idp.previous_event_name IdV: request letter visited
  def idv_resend_letter_visited(
    pending_profile_idv_level: nil,
    **extra
  )
    track_event(
      :idv_resend_letter_visited,
      pending_profile_idv_level:,
      **extra,
    )
  end

  # Acuant SDK errored after loading but before initialization
  # @param [Boolean] success
  # @param [String] error_message
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # @param [String] acuant_version
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_sdk_error_before_init(
    success:,
    error_message:,
    liveness_checking_required:,
    acuant_version:,
    captureAttempts: nil,
    **extra
  )
    track_event(
      :idv_sdk_error_before_init,
      success:,
      error_message: error_message,
      liveness_checking_required:,
      acuant_version: acuant_version,
      captureAttempts: captureAttempts,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User closed the SDK for taking a selfie without submitting a photo
  # @param [String] acuant_version
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_sdk_selfie_image_capture_closed_without_photo(
    acuant_version:,
    captureAttempts: nil,
    selfie_attempts: nil,
    liveness_checking_required: true, # default to true to facilitate CW filtering
    **extra
  )
    track_event(
      :idv_sdk_selfie_image_capture_closed_without_photo,
      acuant_version:,
      captureAttempts:,
      selfie_attempts:,
      liveness_checking_required:,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User encountered an error with the SDK selfie process
  #   Error code 1: camera permission not granted
  #   Error code 2: unexpected errors
  # @param [String] acuant_version
  # @param [Integer] sdk_error_code SDK code for the error encountered
  # @param [String] sdk_error_message SDK message for the error encountered
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_sdk_selfie_image_capture_failed(
    acuant_version:,
    sdk_error_code:,
    sdk_error_message:,
    captureAttempts: nil,
    selfie_attempts: nil,
    liveness_checking_required: true, # default to true to facilitate CW filtering
    **extra
  )
    track_event(
      :idv_sdk_selfie_image_capture_failed,
      acuant_version:,
      sdk_error_code:,
      sdk_error_message:,
      captureAttempts:,
      selfie_attempts:,
      liveness_checking_required:,
      **extra,
    )
  end

  # Camera is ready to detect face for capturing selfie
  # @param [String] acuant_version
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  def idv_sdk_selfie_image_capture_initialized(
    acuant_version:,
    captureAttempts: nil,
    selfie_attempts: nil,
    liveness_checking_required: true, # default to true to facilitate CW filtering
    **extra
  )
    track_event(
      :idv_sdk_selfie_image_capture_initialized,
      acuant_version:,
      captureAttempts:,
      selfie_attempts:,
      liveness_checking_required:,
      **extra,
    )
  end

  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User opened the SDK to take a selfie
  # @param [String] acuant_version
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_sdk_selfie_image_capture_opened(
    acuant_version:,
    captureAttempts: nil,
    selfie_attempts: nil,
    liveness_checking_required: true, # default to true to facilitate CW filtering
    **extra
  )
    track_event(
      :idv_sdk_selfie_image_capture_opened,
      acuant_version:,
      captureAttempts:,
      selfie_attempts:,
      liveness_checking_required:,
      **extra,
    )
  end

  # User opened the SDK to take a selfie
  # @param [String] acuant_version
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  # @param [Integer] selfie_attempts number of selfie captured by SDK
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  def idv_sdk_selfie_image_re_taken(
    acuant_version:,
    captureAttempts: nil,
    selfie_attempts: nil,
    liveness_checking_required: true, # default to true to facilitate CW filtering
    **extra
  )
    track_event(
      :idv_sdk_selfie_image_re_taken,
      acuant_version:,
      captureAttempts:,
      selfie_attempts:,
      liveness_checking_required:,
      **extra,
    )
  end

  # User opened the SDK to take a selfie
  # @param [String] acuant_version
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  # @param [Integer] selfie_attempts number of selfie captured by SDK
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  def idv_sdk_selfie_image_taken(
    acuant_version:,
    captureAttempts: nil,
    selfie_attempts: nil,
    liveness_checking_required: true, # default to true to facilitate CW filtering
    **extra
  )
    track_event(
      :idv_sdk_selfie_image_taken,
      acuant_version:,
      captureAttempts:,
      selfie_attempts:,
      liveness_checking_required:,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User took a selfie image with the SDK, or uploaded a selfie using the file picker
  # @param [String] acuant_version
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
  # @param [Integer] failedImageResubmission
  # @param [String] fingerprint fingerprint of the image added
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Integer] height height of image added in pixels
  # @param [String] mimeType MIME type of image added
  # @param [Integer] size size of image added in bytes
  # @param [String] source
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [Integer] width width of image added in pixels
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_selfie_image_added(
    acuant_version:,
    captureAttempts:,
    selfie_attempts:,
    failedImageResubmission:,
    fingerprint:,
    flow_path:,
    height:,
    mimeType:,
    size:,
    source:,
    liveness_checking_required:,
    width:,
    **extra
  )
    track_event(
      :idv_selfie_image_added,
      acuant_version: acuant_version,
      captureAttempts: captureAttempts,
      selfie_attempts: selfie_attempts,
      failedImageResubmission: failedImageResubmission,
      fingerprint: fingerprint,
      flow_path: flow_path,
      height: height,
      mimeType: mimeType,
      size: size,
      source: source,
      liveness_checking_required: liveness_checking_required,
      width: width,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # rubocop:disable Naming/VariableName,Naming/MethodParameterName,
  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] isDrop
  # @param [String] click_source
  # @param [String] use_alternate_sdk
  # @param [Number] captureAttempts
  # @param [Boolean] liveness_checking_required
  # @param [Hash,nil] proofing_components User's proofing components.
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  def idv_selfie_image_clicked(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    isDrop:,
    click_source:,
    use_alternate_sdk:,
    captureAttempts:,
    liveness_checking_required: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    **_extra
  )
    track_event(
      :idv_selfie_image_clicked,
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      isDrop: isDrop,
      click_source: click_source,
      use_alternate_sdk: use_alternate_sdk,
      captureAttempts: captureAttempts,
      liveness_checking_required: liveness_checking_required,
      proofing_components: proofing_components,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # Tracks when the user visits one of the the session error pages.
  # @param [String] type
  # @param [Integer,nil] remaining_submit_attempts
  #   (previously called "attempts_remaining" and "submit_attempts_remaining")
  def idv_session_error_visited(
    type:,
    remaining_submit_attempts: nil,
    **extra
  )
    track_event(
      'IdV: session error visited',
      type:,
      remaining_submit_attempts:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] exception any exceptions thrown during request
  # @param [String] docv_transaction_token socure transaction token
  # @param [String] reference_id socure interal id for transaction
  # @param [String] language lagnuage presented to user
  # @param [String] step current step of idv to user
  # @param [String] analytics_id id of analytics
  # @param [Boolean] redo_document_capture if user is redoing doc capture
  # @param [Boolean] skip_hybrid_handoff if user is skipping handoff
  # @param [Boolean] selfie_check_required is selfie check required
  # @param [Boolean] opted_in_to_in_person_proofing user opts in to IPP
  # @param [Hash] redirect hash for redirect (url and method)
  # @param [Hash] response_body hash received from socure
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Float] vendor_request_time_in_ms Time it took to upload images & get a response.
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # @param [Boolean] liveness_enabled Whether or not the selfie result is included in response
  # @param [String] vendor which 2rd party we are using for doc auth
  # @param [Hash] document_type type of socument submitted (Drivers Licenese, etc.)
  # The request for socure verification was sent
  def idv_socure_document_request_submitted(
    success:,
    redirect:,
    liveness_checking_required:,
    vendor_request_time_in_ms:,
    vendor:,
    language:,
    step:,
    analytics_id:,
    response_body:,
    redo_document_capture: nil,
    skip_hybrid_handoff: nil,
    selfie_check_required: nil,
    opted_in_to_in_person_proofing: nil,
    errors: nil,
    exception: nil,
    reference_id: nil,
    liveness_enabled: nil,
    document_type: nil,
    docv_transaction_token: nil,
    flow_path: nil,
    **extra
  )
    track_event(
      :idv_socure_document_request_submitted,
      success:,
      redirect:,
      liveness_checking_required:,
      vendor_request_time_in_ms:,
      vendor:,
      language:,
      step:,
      analytics_id:,
      redo_document_capture:,
      skip_hybrid_handoff:,
      selfie_check_required:,
      opted_in_to_in_person_proofing:,
      errors:,
      exception:,
      reference_id:,
      response_body:,
      liveness_enabled:,
      document_type:,
      docv_transaction_token:,
      flow_path:,
      **extra,
    )
  end

  # Socure Reason Codes were downloaded and synced against persisted codes in the database
  # @param [Boolean] success Result from Socure KYC API call
  # @param [Hash] errors Result from resolution proofing
  # @param [String] exception Exception that occured during download or synchronizaiton
  # @param [Array] added_reason_codes New reason codes that were added to the database
  # @param [Array] deactivated_reason_codes Old reason codes that were deactivated
  def idv_socure_reason_code_download(
    success: true,
    errors: nil,
    exception: nil,
    added_reason_codes: nil,
    deactivated_reason_codes: nil,
    **extra
  )
    track_event(
      :idv_socure_reason_code_download,
      success:,
      errors:,
      exception:,
      added_reason_codes:,
      deactivated_reason_codes:,
      **extra,
    )
  end

  # Logs a Socure KYC result alongside a resolution result for later comparison.
  # @param [Hash] socure_result Result from Socure KYC API call
  # @param [Hash] resolution_result Result from resolution proofing
  # @param [String,nil] phone_source Whether the phone number is from MFA or hybrid handoff
  def idv_socure_shadow_mode_proofing_result(
    socure_result:,
    resolution_result:,
    phone_source:,
    **extra
  )
    track_event(
      :idv_socure_shadow_mode_proofing_result,
      resolution_result: resolution_result.to_h,
      phone_source:,
      socure_result: socure_result.to_h,
      **extra,
    )
  end

  # Indicates that no proofing result was found when SocureShadowModeProofingJob
  # attempted to look for one.
  def idv_socure_shadow_mode_proofing_result_missing(**extra)
    track_event(:idv_socure_shadow_mode_proofing_result_missing, **extra)
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String] exception
  # @param [Boolean] billed
  # @param [String] docv_transaction_token socure transaction token
  # @param [Hash] customer_profile socure customer profile
  # @param [String] reference_id socure interal id for transaction
  # @param [Hash] reason_codes socure internal reason codes for accept reject decision
  # @param [Hash] document_type type of socument submitted (Drivers Licenese, etc.)
  # @param [Hash] decision accept or reject of given ID
  # @param [String] user_id internal id of socure user
  # @param [String] state state of ID
  # @param [String] state_id_type type of state issued ID
  # @param [Boolean] async whether or not this worker is running asynchronously
  # @param [Integer] submit_attempts Times that user has tried submitting (previously called
  #   "attempts")
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Float] vendor_request_time_in_ms Time it took to upload images & get a response.
  # @param [Boolean] doc_type_supported
  # @param [Boolean] doc_auth_success
  # @param [Boolean] liveness_checking_required Whether or not the selfie is required
  # @param [Boolean] liveness_enabled Whether or not the selfie result is included in response
  # @param [String] vendor which 2rd party we are using for doc auth
  # @param [Boolean] address_line2_present wether or not we have an address that uses the 2nd line
  # @param [String] zip_code zip code from state issued ID
  # @param [String] birth_year Birth year from document
  # @param [Integer] issue_year Year document was issued
  # @param [Boolean] biometric_comparison_required does doc auth require biometirc
  # The request for socure verification was sent
  def idv_socure_verification_data_requested(
    success:,
    errors:,
    async:,
    reference_id:,
    reason_codes:,
    document_type:,
    decision:,
    state:,
    state_id_type:,
    submit_attempts:,
    remaining_submit_attempts:,
    liveness_checking_required:,
    issue_year:,
    vendor_request_time_in_ms:,
    doc_type_supported:,
    doc_auth_success:,
    vendor:,
    address_line2_present:,
    zip_code:,
    birth_year:,
    liveness_enabled:,
    biometric_comparison_required:,
    customer_profile: nil,
    docv_transaction_token: nil,
    user_id: nil,
    exception: nil,
    flow_path: nil,
    billed: nil,
    **extra
  )
    track_event(
      :idv_socure_verification_data_requested,
      success:,
      errors:,
      exception:,
      billed:,
      docv_transaction_token:,
      customer_profile:,
      reference_id:,
      reason_codes:,
      document_type:,
      decision:,
      user_id:,
      state:,
      state_id_type:,
      async:,
      submit_attempts:,
      remaining_submit_attempts:,
      flow_path:,
      liveness_checking_required:,
      vendor_request_time_in_ms:,
      doc_type_supported:,
      doc_auth_success:,
      vendor:,
      address_line2_present:,
      zip_code:,
      birth_year:,
      issue_year:,
      liveness_enabled:,
      biometric_comparison_required:,
      **extra,
    )
  end

  # @param [String] step
  # @param [String] location
  # @param [Hash,nil] proofing_components User's current proofing components
  # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
  # @option proofing_components [String,nil] 'document_type' Type of ID used to verify
  # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
  # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
  # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
  # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
  # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
  # @param [boolean,nil] cancelled_enrollment Whether the user's IPP enrollment has been canceled
  # @param [String,nil] enrollment_code IPP enrollment code
  # @param [Integer,nil] enrollment_id ID of the associated IPP enrollment record
  # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
  # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
  # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
  # User started over idv
  def idv_start_over(
    step:,
    location:,
    cancelled_enrollment: nil,
    enrollment_code: nil,
    enrollment_id: nil,
    proofing_components: nil,
    active_profile_idv_level: nil,
    pending_profile_idv_level: nil,
    profile_history: nil,
    **extra
  )
    track_event(
      'IdV: start over',
      step: step,
      location: location,
      proofing_components: proofing_components,
      cancelled_enrollment: cancelled_enrollment,
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      active_profile_idv_level: active_profile_idv_level,
      pending_profile_idv_level: pending_profile_idv_level,
      profile_history: profile_history,
      **extra,
    )
  end

  # The JSON body of the response returned from Threatmetrix. PII has been removed.
  # @param [Hash] response_body The response body returned by ThreatMetrix
  def idv_threatmetrix_response_body(
    response_body: nil,
    **extra
  )
    track_event(
      :idv_threatmetrix_response_body,
      response_body: response_body,
      **extra,
    )
  end

  # Track when USPS auth token refresh job completed
  def idv_usps_auth_token_refresh_job_completed(**extra)
    track_event(
      'UspsAuthTokenRefreshJob: Completed',
      **extra,
    )
  end

  # Track when USPS auth token refresh job encounters a network error
  # @param [String] exception_class
  # @param [String] exception_message
  def idv_usps_auth_token_refresh_job_network_error(exception_class:, exception_message:, **extra)
    track_event(
      'UspsAuthTokenRefreshJob: Network error',
      exception_class: exception_class,
      exception_message: exception_message,
      **extra,
    )
  end

  # Track when USPS auth token refresh job started
  def idv_usps_auth_token_refresh_job_started(**extra)
    track_event(
      'UspsAuthTokenRefreshJob: Started',
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account verification submitted
  # @identity.idp.previous_event_name IdV: GPO verification submitted
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [DateTime] enqueued_at When was this letter enqueued
  # @param [Integer] which_letter Sorted by enqueue time, which letter had this code
  # @param [Integer] letter_count How many letters did the user enqueue for this profile
  # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
  # @param [String] initiating_service_provider The initiating service provider issuer
  # @param [Integer] submit_attempts Number of attempts to enter a correct code
  #                  (previously called "attempts")
  # @param [Boolean] pending_in_person_enrollment
  # @param [Boolean] fraud_check_failed
  # @see Reporting::IdentityVerificationReport#query This event is used by the identity verification
  #       report. Changes here should be reflected there.
  # GPO verification submitted
  def idv_verify_by_mail_enter_code_submitted(
    success:,
    errors:,
    enqueued_at:,
    which_letter:,
    letter_count:,
    profile_age_in_seconds:,
    initiating_service_provider:,
    submit_attempts:,
    pending_in_person_enrollment:,
    fraud_check_failed:,
    error_details: nil,
    **extra
  )
    track_event(
      'IdV: enter verify by mail code submitted',
      success:,
      errors:,
      error_details:,
      enqueued_at:,
      which_letter:,
      letter_count:,
      profile_age_in_seconds:,
      initiating_service_provider:,
      submit_attempts:,
      pending_in_person_enrollment:,
      fraud_check_failed:,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account verification visited
  # @identity.idp.previous_event_name IdV: GPO verification visited
  # Visited page used to enter address verification code received via US mail.
  # @param [String,nil] source The source for the visit (i.e., "gpo_reminder_email").
  # @param [Boolean] otp_rate_limited Whether the user is rate-limited
  # @param [Boolean] user_can_request_another_letter Whether user can request another letter
  def idv_verify_by_mail_enter_code_visited(
    source:,
    otp_rate_limited:,
    user_can_request_another_letter:,
    **extra
  )
    track_event(
      'IdV: enter verify by mail code visited',
      source:,
      otp_rate_limited:,
      user_can_request_another_letter:,
      **extra,
    )
  end

  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [Integer] submit_attempts Times that user has tried submitting document capture
  # The user clicked the troubleshooting option to start in-person proofing
  def idv_verify_in_person_troubleshooting_option_clicked(
    flow_path:,
    opted_in_to_in_person_proofing:,
    submit_attempts:,
    **extra
  )
    track_event(
      'IdV: verify in person troubleshooting option clicked',
      flow_path: flow_path,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      submit_attempts: submit_attempts,
      **extra,
    )
  end

  # The user ended up at the "Verify info" screen without a Threatmetrix session id.
  def idv_verify_info_missing_threatmetrix_session_id(**extra)
    track_event(:idv_verify_info_missing_threatmetrix_session_id, **extra)
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] location
  # @param [Boolean] use_alternate_sdk
  def idv_warning_action_triggered(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    location:,
    use_alternate_sdk:,
    **extra
  )
    track_event(
      'Frontend: IdV: warning action triggered',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      location: location,
      use_alternate_sdk: use_alternate_sdk,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] error_message_displayed
  # @param ["hybrid","standard"] flow_path Document capture user flow
  # @param [String] heading
  # @param [String] location
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param [String] subheading
  # @param [Boolean] use_alternate_sdk
  # @param [Boolean] liveness_checking_required
  def idv_warning_shown(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    error_message_displayed:,
    flow_path:,
    heading:,
    location:,
    remaining_submit_attempts:,
    subheading:,
    use_alternate_sdk:,
    liveness_checking_required:,
    **extra
  )
    track_event(
      'Frontend: IdV: warning shown',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      error_message_displayed: error_message_displayed,
      flow_path: flow_path,
      heading: heading,
      location: location,
      remaining_submit_attempts: remaining_submit_attempts,
      subheading: subheading,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
      **extra,
    )
  end

  # @param [String] controller
  # @param [Boolean] user_signed_in
  # Authenticity token (CSRF) is invalid
  def invalid_authenticity_token(
    controller:,
    user_signed_in: nil,
    **extra
  )
    track_event(
      'Invalid Authenticity Token',
      controller: controller,
      user_signed_in: user_signed_in,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] method
  # Logout Initiated
  def logout_initiated(
    success: nil,
    client_id: nil,
    sp_initiated: nil,
    oidc: nil,
    client_id_parameter_present: nil,
    id_token_hint_parameter_present: nil,
    saml_request_valid: nil,
    errors: nil,
    error_details: nil,
    method: nil,
    **extra
  )
    track_event(
      'Logout Initiated',
      success: success,
      client_id: client_id,
      client_id_parameter_present: client_id_parameter_present,
      id_token_hint_parameter_present: id_token_hint_parameter_present,
      errors: errors,
      error_details: error_details,
      sp_initiated: sp_initiated,
      oidc: oidc,
      saml_request_valid: saml_request_valid,
      method: method,
      **extra,
    )
  end

  # @param [Boolean] success Whether authentication was successful
  # @param [Hash] errors Authentication error reasons, if unsuccessful
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # @param [Boolean] new_device Whether the user is authenticating from a new device
  # @param [String] multi_factor_auth_method Authentication method used
  # @param [String] multi_factor_auth_method_created_at When the authentication method was created
  # @param [Integer] attempts number of MFA setup attempts
  # @param [Integer] auth_app_configuration_id Database ID of authentication app configuration
  # @param [Integer] piv_cac_configuration_id Database ID of PIV/CAC configuration
  # @param [String] piv_cac_configuration_dn_uuid PIV/CAC X509 distinguished name UUID
  # @param [String, nil] key_id PIV/CAC key_id from PKI service
  # @param [Integer] webauthn_configuration_id Database ID of WebAuthn configuration
  # @param [String] webauthn_aaguid AAGUID valule of WebAuthn configuration
  # @param [Integer] phone_configuration_id Database ID of phone configuration
  # @param [Boolean] confirmation_for_add_phone Whether authenticating while adding phone
  # @param [String] area_code Area code of phone number
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @param [String] frontend_error Name of error that occurred in frontend during submission
  # @param [Boolean] in_account_creation_flow Whether user is going through account creation flow
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # Multi-Factor Authentication
  def multi_factor_auth(
    success:,
    multi_factor_auth_method:,
    enabled_mfa_methods_count:,
    new_device:,
    errors: nil,
    error_details: nil,
    context: nil,
    attempts: nil,
    multi_factor_auth_method_created_at: nil,
    auth_app_configuration_id: nil,
    piv_cac_configuration_id: nil,
    piv_cac_configuration_dn_uuid: nil,
    key_id: nil,
    webauthn_configuration_id: nil,
    webauthn_aaguid: nil,
    confirmation_for_add_phone: nil,
    phone_configuration_id: nil,
    area_code: nil,
    country_code: nil,
    phone_fingerprint: nil,
    frontend_error: nil,
    in_account_creation_flow: nil,
    **extra
  )
    track_event(
      'Multi-Factor Authentication',
      success:,
      errors:,
      error_details:,
      context:,
      new_device:,
      attempts:,
      multi_factor_auth_method:,
      multi_factor_auth_method_created_at:,
      auth_app_configuration_id:,
      piv_cac_configuration_id:,
      piv_cac_configuration_dn_uuid:,
      key_id:,
      webauthn_configuration_id:,
      webauthn_aaguid:,
      confirmation_for_add_phone:,
      phone_configuration_id:,
      area_code:,
      country_code:,
      phone_fingerprint:,
      frontend_error:,
      in_account_creation_flow:,
      enabled_mfa_methods_count:,
      **extra,
    )
  end

  # Tracks when the the user has added the MFA method phone to their account
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
  # @param [Boolean] in_account_creation_flow whether user is going through creation flow
  # @param ['phone'] method_name Authentication method added
  def multi_factor_auth_added_phone(
    enabled_mfa_methods_count:,
    recaptcha_annotation:,
    in_account_creation_flow:,
    method_name: :phone,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: Added phone',
      method_name:,
      enabled_mfa_methods_count:,
      recaptcha_annotation:,
      in_account_creation_flow:,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Multi-Factor Authentication: Added PIV_CAC
  # Tracks when the user has added the MFA method piv_cac to their account
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [Boolean] in_account_creation_flow whether user is going through creation flow
  # @param ['piv_cac'] method_name Authentication method added
  # @param [Integer] attempts number of MFA setup attempts
  def multi_factor_auth_added_piv_cac(
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    method_name: :piv_cac,
    attempts: nil,
    **extra
  )
    track_event(
      :multi_factor_auth_added_piv_cac,
      method_name:,
      enabled_mfa_methods_count:,
      in_account_creation_flow:,
      attempts:,
      **extra,
    )
  end

  # Tracks when the user has added the MFA method TOTP to their account
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [Boolean] in_account_creation_flow whether user is going through creation flow
  # @param ['totp'] method_name Authentication method added
  def multi_factor_auth_added_totp(
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    method_name: :totp,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: Added TOTP',
      method_name:,
      in_account_creation_flow:,
      enabled_mfa_methods_count:,
      **extra,
    )
  end

  # A user has downloaded their backup codes
  def multi_factor_auth_backup_code_download
    track_event('Multi-Factor Authentication: download backup code')
  end

  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # User visited the page to enter a backup code as their MFA
  def multi_factor_auth_enter_backup_code_visit(context:, **extra)
    track_event(
      'Multi-Factor Authentication: enter backup code visited',
      context: context,
      **extra,
    )
  end

  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # @param [Integer] attempts number of MFA setup attempts
  # @param [String] multi_factor_auth_method
  # @param [Boolean] confirmation_for_add_phone
  # @param [Integer] phone_configuration_id
  # @param [String] area_code Area code of phone number
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @param [Boolean] in_account_creation_flow Whether user is going through account creation flow
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # Multi-Factor Authentication enter OTP visited
  def multi_factor_auth_enter_otp_visit(
    context:,
    multi_factor_auth_method:,
    confirmation_for_add_phone:,
    phone_configuration_id:,
    area_code:,
    country_code:,
    phone_fingerprint:,
    in_account_creation_flow:,
    enabled_mfa_methods_count:,
    attempts: nil,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: enter OTP visited',
      context:,
      attempts:,
      multi_factor_auth_method:,
      confirmation_for_add_phone:,
      phone_configuration_id:,
      area_code:,
      country_code:,
      phone_fingerprint:,
      in_account_creation_flow:,
      enabled_mfa_methods_count:,
      **extra,
    )
  end

  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # User visited the page to enter a personal key as their mfa (legacy flow)
  def multi_factor_auth_enter_personal_key_visit(context:, **extra)
    track_event(
      'Multi-Factor Authentication: enter personal key visited',
      context: context,
      **extra,
    )
  end

  # @identity.idp.previous_event_name 'Multi-Factor Authentication: enter PIV CAC visited'
  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # @param ["piv_cac"] multi_factor_auth_method
  # @param [Integer, nil] piv_cac_configuration_id PIV/CAC configuration database ID
  # @param [Boolean] new_device Whether the user is authenticating from a new device
  # User used a PIV/CAC as their mfa
  def multi_factor_auth_enter_piv_cac(
    context:,
    multi_factor_auth_method:,
    piv_cac_configuration_id:,
    new_device:,
    **extra
  )
    track_event(
      :multi_factor_auth_enter_piv_cac,
      context: context,
      multi_factor_auth_method: multi_factor_auth_method,
      piv_cac_configuration_id: piv_cac_configuration_id,
      new_device:,
      **extra,
    )
  end

  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # User visited the page to enter a TOTP as their mfa
  def multi_factor_auth_enter_totp_visit(context:, **extra)
    track_event('Multi-Factor Authentication: enter TOTP visited', context: context, **extra)
  end

  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # @param ["webauthn","webauthn_platform"] multi_factor_auth_method which webauthn method was used,
  #   webauthn means a roaming authenticator like a yubikey, webauthn_platform means a platform
  #   authenticator like face or touch ID
  # @param [Integer, nil] webauthn_configuration_id webauthn database ID
  # @param [String] multi_factor_auth_method_created_at When the authentication method was created
  # User visited the page to authenticate with webauthn (yubikey, face ID or touch ID)
  def multi_factor_auth_enter_webauthn_visit(
    context:,
    multi_factor_auth_method:,
    webauthn_configuration_id:,
    multi_factor_auth_method_created_at:,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: enter webAuthn authentication visited',
      context:,
      multi_factor_auth_method:,
      webauthn_configuration_id:,
      multi_factor_auth_method_created_at:,
      **extra,
    )
  end

  # Max multi factor auth attempts met
  def multi_factor_auth_max_attempts
    track_event('Multi-Factor Authentication: max attempts reached')
  end

  # Max multi factor max otp sends reached
  def multi_factor_auth_max_sends
    track_event('Multi-Factor Authentication: max otp sends reached')
  end

  # Multi factor selected from auth options list
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] selection
  # @param [integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [Hash] mfa_method_counts Hash of MFA method with the number of that method on the account
  def multi_factor_auth_option_list(
    success:,
    errors:,
    selection:,
    enabled_mfa_methods_count:,
    mfa_method_counts:,
    error_details: nil,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: option list',
      success:,
      errors:,
      error_details:,
      selection:,
      enabled_mfa_methods_count:,
      mfa_method_counts:,
      **extra,
    )
  end

  # User visited the list of multi-factor options to use
  def multi_factor_auth_option_list_visit
    track_event('Multi-Factor Authentication: option list visited')
  end

  # Multi factor auth phone setup
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [String] area_code
  # @param [String] carrier Pinpoint detected phone carrier
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] phone_type Pinpoint phone classification type
  # @param [Array<String>] types Phonelib parsed phone types
  def multi_factor_auth_phone_setup(
      success:,
      errors:,
      otp_delivery_preference:,
      area_code:,
      carrier:,
      country_code:,
      phone_type:,
      types:,
      error_details: nil,
      **extra
    )
    track_event(
      'Multi-Factor Authentication: phone setup',
      success:,
      errors:,
      error_details:,
      otp_delivery_preference:,
      area_code:,
      carrier:,
      country_code:,
      phone_type:,
      types:,
      **extra,
    )
  end

  # Tracks when a user sets up a multi factor auth method
  # @param [Boolean] success Whether authenticator setup was successful
  # @param [Hash] errors Authenticator setup error reasons, if unsuccessful
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] multi_factor_auth_method
  # @param [Boolean] in_account_creation_flow whether user is going through account creation flow
  # @param [integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [String] multi_factor_auth_method_created_at When the authentication method was created
  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # @param [Boolean] confirmation_for_add_phone Whether authenticating while adding phone
  # @param [String] area_code Area code of phone number
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @param [Integer] phone_configuration_id Database ID of phone configuration
  # @param [Integer] auth_app_configuration_id Database ID of authentication app configuration
  # @param [Boolean] totp_secret_present Whether TOTP secret was present in form validation
  # @param [Boolean] new_device Whether the user is authenticating from a new device
  # @param [String, nil] key_id PIV/CAC key_id from PKI service
  # @param [Hash] mfa_method_counts Hash of MFA method with the number of that method on the account
  # @param [Hash] authenticator_data_flags WebAuthn authenticator data flags
  # @param [Integer] attempts number of MFA setup attempts
  # @param [String, nil] aaguid AAGUID value of WebAuthn device
  # @param [String[], nil] unknown_transports Array of unrecognized WebAuthn transports, intended to
  #   be used in case of future specification changes.
  # @param [:authentication, :account_creation, nil] webauthn_platform_recommended A/B test for
  # recommended Face or Touch Unlock setup, if applicable.
  def multi_factor_auth_setup(
    success:,
    multi_factor_auth_method:,
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    errors: nil,
    error_details: nil,
    multi_factor_auth_method_created_at: nil,
    context: nil,
    confirmation_for_add_phone: nil,
    area_code: nil,
    country_code: nil,
    phone_fingerprint: nil,
    phone_configuration_id: nil,
    totp_secret_present: nil,
    auth_app_configuration_id: nil,
    new_device: nil,
    key_id: nil,
    mfa_method_counts: nil,
    authenticator_data_flags: nil,
    attempts: nil,
    aaguid: nil,
    unknown_transports: nil,
    webauthn_platform_recommended: nil,
    **extra
  )
    track_event(
      'Multi-Factor Authentication Setup',
      success:,
      errors:,
      error_details:,
      multi_factor_auth_method:,
      in_account_creation_flow:,
      enabled_mfa_methods_count:,
      multi_factor_auth_method_created_at:,
      context:,
      confirmation_for_add_phone:,
      area_code:,
      country_code:,
      phone_fingerprint:,
      phone_configuration_id:,
      totp_secret_present:,
      auth_app_configuration_id:,
      new_device:,
      key_id:,
      mfa_method_counts:,
      authenticator_data_flags:,
      attempts:,
      aaguid:,
      unknown_transports:,
      webauthn_platform_recommended:,
      **extra,
    )
  end

  # @param [String] location Placement location
  # Logged when a browser with JavaScript disabled loads the detection stylesheet
  def no_js_detect_stylesheet_loaded(location:, **extra)
    track_event(:no_js_detect_stylesheet_loaded, location:, **extra)
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] method
  # @param [String] original_method Method of referring request
  # OIDC Logout Requested
  def oidc_logout_requested(
    success:,
    errors:,
    error_details: nil,
    client_id: nil,
    sp_initiated: nil,
    oidc: nil,
    client_id_parameter_present: nil,
    id_token_hint_parameter_present: nil,
    saml_request_valid: nil,
    method: nil,
    original_method: nil,
    **extra
  )
    track_event(
      'OIDC Logout Requested',
      success: success,
      client_id: client_id,
      client_id_parameter_present: client_id_parameter_present,
      id_token_hint_parameter_present: id_token_hint_parameter_present,
      errors: errors,
      error_details: error_details,
      sp_initiated: sp_initiated,
      oidc: oidc,
      saml_request_valid: saml_request_valid,
      method: method,
      original_method: original_method,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] method
  # OIDC Logout Submitted
  def oidc_logout_submitted(
    success: nil,
    client_id: nil,
    sp_initiated: nil,
    oidc: nil,
    client_id_parameter_present: nil,
    id_token_hint_parameter_present: nil,
    saml_request_valid: nil,
    errors: nil,
    error_details: nil,
    method: nil,
    **extra
  )
    track_event(
      'OIDC Logout Submitted',
      success: success,
      client_id: client_id,
      client_id_parameter_present: client_id_parameter_present,
      id_token_hint_parameter_present: id_token_hint_parameter_present,
      errors: errors,
      error_details: error_details,
      sp_initiated: sp_initiated,
      oidc: oidc,
      saml_request_valid: saml_request_valid,
      method: method,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] method
  # OIDC Logout Visited
  def oidc_logout_visited(
    success:,
    errors:,
    client_id: nil,
    sp_initiated: nil,
    oidc: nil,
    client_id_parameter_present: nil,
    id_token_hint_parameter_present: nil,
    saml_request_valid: nil,
    error_details: nil,
    method: nil,
    **extra
  )
    track_event(
      'OIDC Logout Page Visited',
      success: success,
      client_id: client_id,
      client_id_parameter_present: client_id_parameter_present,
      id_token_hint_parameter_present: id_token_hint_parameter_present,
      errors: errors,
      error_details: error_details,
      sp_initiated: sp_initiated,
      oidc: oidc,
      saml_request_valid: saml_request_valid,
      method: method,
      **extra,
    )
  end

  # Tracks when a sucessful openid authorization request is returned
  # @param [Boolean] success Whether form validations were succcessful
  # @param [Boolean] user_sp_authorized Whether user granted consent during this authorization
  # @param [String] client_id
  # @param [String] code_digest hash of returned "code" param
  def openid_connect_authorization_handoff(
    success:,
    user_sp_authorized:,
    client_id:,
    code_digest:,
    **extra
  )
    track_event(
      'OpenID Connect: authorization request handoff',
      success:,
      user_sp_authorized:,
      client_id:,
      code_digest:,
      **extra,
    )
  end

  # Tracks when an openid connect bearer token authentication request is made
  # @param [Boolean] success Whether form validation was successful
  # @param [Integer] ial
  # @param [String] client_id Service Provider issuer
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  def openid_connect_bearer_token(success:, ial:, client_id:, errors:, error_details: nil, **extra)
    track_event(
      'OpenID Connect: bearer token authentication',
      success:,
      ial:,
      client_id:,
      errors:,
      error_details:,
      **extra,
    )
  end

  # Tracks when openid authorization request is made
  # @param [Boolean] success Whether form validations were succcessful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] prompt OIDC prompt parameter
  # @param [Boolean] allow_prompt_login Whether service provider is configured to allow prompt=login
  # @param [Boolean] code_challenge_present Whether code challenge is present
  # @param [Boolean, nil] service_provider_pkce Whether service provider is configured with PKCE
  # @param [String, nil] referer Request referer
  # @param [String] client_id
  # @param [String] scope
  # @param [Array] acr_values
  # @param [Array] vtr
  # @param [String, nil] vtr_param
  # @param [Boolean] unauthorized_scope
  # @param [Boolean] user_fully_authenticated
  # @param [String] unknown_authn_contexts space separated list of unknown contexts
  def openid_connect_request_authorization(
    success:,
    errors:,
    prompt:,
    allow_prompt_login:,
    code_challenge_present:,
    service_provider_pkce:,
    referer:,
    client_id:,
    scope:,
    acr_values:,
    vtr:,
    vtr_param:,
    unauthorized_scope:,
    user_fully_authenticated:,
    error_details: nil,
    unknown_authn_contexts: nil,
    **extra
  )
    track_event(
      'OpenID Connect: authorization request',
      success:,
      errors:,
      error_details:,
      prompt:,
      allow_prompt_login:,
      code_challenge_present:,
      service_provider_pkce:,
      referer:,
      client_id:,
      scope:,
      acr_values:,
      vtr:,
      vtr_param:,
      unauthorized_scope:,
      user_fully_authenticated:,
      unknown_authn_contexts:,
      **extra,
    )
  end

  # Tracks when an openid connect token request is made
  # @param [Boolean] success Whether the form was submitted successfully.
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] client_id Service provider issuer
  # @param [String] user_id User ID associated with code
  # @param [String] code_digest hash of "code" param
  # @param [Integer, nil] expires_in time to expiration of token
  # @param [Integer, nil] ial ial level of identity
  # @param [Boolean] code_verifier_present Whether code verifier parameter was present
  # @param [Boolean, nil] service_provider_pkce Whether service provider is configured for PKCE. Nil
  # if the service provider is unknown.
  def openid_connect_token(
    client_id:,
    success:,
    errors:,
    user_id:,
    code_digest:,
    expires_in:,
    ial:,
    code_verifier_present:,
    service_provider_pkce:,
    error_details: nil,
    **extra
  )
    track_event(
      'OpenID Connect: token',
      success:,
      errors:,
      error_details:,
      client_id:,
      user_id:,
      code_digest:,
      expires_in:,
      ial:,
      code_verifier_present:,
      service_provider_pkce:,
      **extra,
    )
  end

  # Tracks when user makes an otp delivery selection
  # @param [Boolean] success Whether the form was submitted successfully.
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param ["authentication","reauthentication","confirmation"] context User session context
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [Boolean] resend True if the user re-requested a code
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] area_code Area code of phone number
  def otp_delivery_selection(
    success:,
    errors:,
    context:,
    otp_delivery_preference:,
    resend:,
    country_code:,
    area_code:,
    error_details: nil,
    **extra
  )
    track_event(
      'OTP: Delivery Selection',
      success:,
      errors:,
      error_details:,
      context:,
      otp_delivery_preference:,
      resend:,
      country_code:,
      area_code:,
      **extra,
    )
  end

  # Tracks if otp phone validation failed
  # @identity.idp.previous_event_name Twilio Phone Validation Failed
  # @param [String] error
  # @param [string] message
  # @param [String] context
  # @param [String] country
  def otp_phone_validation_failed(error:, message:, context:, country:, **extra)
    track_event(
      'Vendor Phone Validation failed',
      error: error,
      message: message,
      context: context,
      country: country,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Boolean] active_profile_present Whether active profile existed at time of change
  # @param [Boolean] pending_profile_present Whether pending profile existed at time of change
  # @param [Boolean] required_password_change Whether password change was forced due to compromised
  #   password
  # The user updated their password
  def password_changed(
    success:,
    errors:,
    active_profile_present:,
    pending_profile_present:,
    required_password_change:,
    error_details: nil,
    **extra
  )
    track_event(
      'Password Changed',
      success:,
      errors:,
      error_details:,
      active_profile_present:,
      pending_profile_present:,
      required_password_change:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] user_id UUID of the user
  # @param [Boolean] request_id_present Whether request_id URL parameter is present
  # The user added a password after verifying their email for account creation
  def password_creation(
    success:,
    errors:,
    user_id:,
    request_id_present:,
    error_details: nil,
    **extra
  )
    track_event(
      'Password Creation',
      success:,
      errors:,
      error_details:,
      user_id:,
      request_id_present:,
      **extra,
    )
  end

  # The user got their password incorrect the max number of times, their session was terminated
  def password_max_attempts
    track_event('Password Max Attempts Reached')
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Boolean, nil] confirmed if the account the reset is being requested for has a
  #   confirmed email
  # @param [Boolean, nil] active_profile if the account the reset is being requested for has an
  #   active proofed profile
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # The user entered an email address to request a password reset
  def password_reset_email(
    success:,
    errors:,
    confirmed:,
    active_profile:,
    error_details: {},
    **extra
  )
    track_event(
      'Password Reset: Email Submitted',
      success:,
      errors:,
      error_details:,
      confirmed:,
      active_profile:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Boolean] profile_deactivated if the active profile for the account was deactivated
  #   (the user will need to use their personal key to reactivate their profile)
  # @param [Boolean] pending_profile_invalidated Whether a pending profile was invalidated as a
  #   result of the password reset
  # @param [String] pending_profile_pending_reasons Comma-separated list of the pending states
  #   associated with the associated profile.
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # The user changed the password for their account via the password reset flow
  def password_reset_password(
    success:,
    errors:,
    profile_deactivated:,
    pending_profile_invalidated:,
    pending_profile_pending_reasons:,
    error_details: {},
    **extra
  )
    track_event(
      'Password Reset: Password Submitted',
      success:,
      errors:,
      error_details:,
      profile_deactivated:,
      pending_profile_invalidated:,
      pending_profile_pending_reasons:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] user_id UUID of the user to receive password token
  # A password token has been sent for user
  def password_reset_token(success:, errors:, user_id:, error_details: nil, **extra)
    track_event(
      'Password Reset: Token Submitted',
      success:,
      errors:,
      error_details:,
      user_id:,
      **extra,
    )
  end

  # Password reset form has been visited.
  def password_reset_visit
    track_event('Password Reset: Email Form Visited')
  end

  # Pending account reset cancelled
  def pending_account_reset_cancelled
    track_event('Pending account reset cancelled')
  end

  # Pending account reset visited
  def pending_account_reset_visited
    track_event('Pending account reset visited')
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] emails Number of email addresses the notification was sent to
  # @param [Array<String>] sms_message_ids AWS Pinpoint SMS message IDs for each phone number that
  #   was notified
  # Alert user if a personal key was used to sign in
  def personal_key_alert_about_sign_in(
    success:,
    errors:,
    emails:,
    sms_message_ids:,
    error_details: nil,
    **extra
  )
    track_event(
      'Personal key: Alert user about sign in',
      success:,
      errors:,
      error_details:,
      emails:,
      sms_message_ids:,
      **extra,
    )
  end

  # Account reactivated with personal key
  def personal_key_reactivation
    track_event('Personal key reactivation: Account reactivated with personal key')
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # Personal key form submitted
  def personal_key_reactivation_submitted(
    success:,
    errors:,
    error_details: nil,
    **extra
  )
    track_event(
      'Personal key reactivation: Personal key form submitted',
      success:,
      errors:,
      error_details:,
      **extra,
    )
  end

  # Personal key reactivation visited
  def personal_key_reactivation_visited
    track_event('Personal key reactivation: Personal key form visited')
  end

  # @param [Boolean] personal_key_present if personal key is present
  # Personal key viewed
  def personal_key_viewed(personal_key_present:, **extra)
    track_event(
      'Personal key viewed',
      personal_key_present: personal_key_present,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] delivery_preference
  # @param [Integer] phone_configuration_id
  # @param [Boolean] make_default_number
  # User has submitted a change in phone number
  def phone_change_submitted(
    success:,
    errors:,
    delivery_preference:,
    phone_configuration_id:,
    make_default_number:,
    error_details: nil,
    **extra
  )
    track_event(
      'Phone Number Change: Form submitted',
      success:,
      errors:,
      error_details:,
      delivery_preference:,
      phone_configuration_id:,
      make_default_number:,
      **extra,
    )
  end

  # User has viewed the page to change their phone number
  def phone_change_viewed
    track_event('Phone Number Change: Visited')
  end

  # @param [Boolean] success
  # @param [Integer] phone_configuration_id
  # Tracks a phone number deletion event
  def phone_deletion(success:, phone_configuration_id:, **extra)
    track_event(
      'Phone Number Deletion: Submitted',
      success: success,
      phone_configuration_id: phone_configuration_id,
      **extra,
    )
  end

  # @param [String] country_code The new selected country code
  # User changes the selected country in the frontend phone input component
  def phone_input_country_changed(country_code:, **extra)
    track_event(:phone_input_country_changed, country_code:, **extra)
  end

  # @identity.idp.previous_event_name User Registration: piv cac disabled
  # @identity.idp.previous_event_name PIV CAC disabled
  # @identity.idp.previous_event_name piv_cac_disabled
  # @param [Boolean] success
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] configuration_id
  # Tracks when user attempts to delete a PIV/CAC configuraton
  def piv_cac_delete_submitted(
    success:,
    configuration_id:,
    error_details: nil,
    **extra
  )
    track_event(
      :piv_cac_delete_submitted,
      success:,
      error_details:,
      configuration_id:,
      **extra,
    )
  end

  # @identity.idp.previous_event_name PIV/CAC login
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [String, nil] key_id PIV/CAC key_id from PKI service
  # @param [Boolean] new_device Whether the user is authenticating from a new device
  # Tracks piv cac login event
  def piv_cac_login(success:, errors:, key_id:, new_device:, **extra)
    track_event(
      :piv_cac_login,
      success:,
      errors:,
      key_id:,
      new_device:,
      **extra,
    )
  end

  def piv_cac_login_visited
    track_event(:piv_cac_login_visited)
  end

  # User submits prompt to replace PIV/CAC after failing to authenticate due to mismatched subject
  # @param [Boolean] add_piv_cac_after_2fa User chooses to replace PIV/CAC authenticator
  def piv_cac_mismatch_submitted(add_piv_cac_after_2fa:, **extra)
    track_event(:piv_cac_mismatch_submitted, add_piv_cac_after_2fa:, **extra)
  end

  # User visits prompt to replace PIV/CAC after failing to authenticate due to mismatched subject
  # @param [Boolean] piv_cac_required Partner requires HSPD12 authentication
  # @param [Boolean] has_other_authentication_methods User has non-PIV authentication methods
  def piv_cac_mismatch_visited(piv_cac_required:, has_other_authentication_methods:, **extra)
    track_event(
      :piv_cac_mismatch_visited,
      piv_cac_required:,
      has_other_authentication_methods:,
      **extra,
    )
  end

  # @param [String] action what action user made
  # Tracks when user submits an action on Piv Cac recommended page
  def piv_cac_recommended(action: nil, **extra)
    track_event(
      :piv_cac_recommended,
      action: action,
      **extra,
    )
  end

  # Tracks when user visits piv cac recommended
  def piv_cac_recommended_visited
    track_event(:piv_cac_recommended_visited)
  end

  # @identity.idp.previous_event_name User Registration: piv cac setup visited
  # @identity.idp.previous_event_name PIV CAC setup visited
  # Tracks when user's piv cac setup
  # @param [Boolean] in_account_creation_flow Whether user is going through account creation
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [Integer] attempts number of MFA setup attempts
  def piv_cac_setup_visited(
    in_account_creation_flow:,
    enabled_mfa_methods_count: nil,
    attempts: nil,
    **extra
  )
    track_event(
      :piv_cac_setup_visited,
      in_account_creation_flow:,
      enabled_mfa_methods_count:,
      attempts:,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] configuration_id
  # Tracks when user submits a name change for a PIV/CAC configuraton
  def piv_cac_update_name_submitted(
      success:,
      configuration_id:,
      error_details: nil,
      **extra
    )
    track_event(
      :piv_cac_update_name_submitted,
      success:,
      error_details:,
      configuration_id:,
      **extra,
    )
  end

  # @param [String] redirect_url URL user was directed to
  # @param [String, nil] step which step
  # @param [String, nil] location which part of a step, if applicable
  # @param ["idv", String, nil] flow which flow
  # User was redirected to the login.gov policy page
  def policy_redirect(redirect_url:, step: nil, location: nil, flow: nil, **extra)
    track_event(
      'Policy Page Redirect',
      redirect_url: redirect_url,
      step: step,
      location: location,
      flow: flow,
      **extra,
    )
  end

  # @param [String] error
  # Tracks if a Profile encryption is invalid
  def profile_encryption_invalid(error:, **extra)
    track_event('Profile Encryption: Invalid', error: error, **extra)
  end

  # @see #profile_personal_key_create_notifications
  # User has chosen to receive a new personal key
  def profile_personal_key_create
    track_event('Profile: Created new personal key')
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] emails Number of email addresses the notification was sent to
  # @param [Array<String>] sms_message_ids AWS Pinpoint SMS message IDs for each phone number that
  #   was notified
  # User has chosen to receive a new personal key, contains stats about notifications that
  # were sent to phone numbers and email addresses for the user
  def profile_personal_key_create_notifications(
    success:,
    errors:,
    emails:,
    sms_message_ids:,
    error_details: nil,
    **extra
  )
    track_event(
      'Profile: Created new personal key notifications',
      success:,
      errors:,
      error_details:,
      emails:,
      sms_message_ids:,
      **extra,
    )
  end

  # User has visited the page that lets them confirm if they want a new personal key
  def profile_personal_key_visit
    track_event('Profile: Visited new personal key')
  end

  # @identity.idp.previous_event_name Proofing Address Timeout
  # The job for address verification (PhoneFinder) did not record a result in the expected
  # place during the expected time frame
  def proofing_address_result_missing
    track_event('Proofing Address Result Missing')
  end

  # Tracks when a user triggered a rate limiter
  # @param [String] limiter_type Name of the rate limiter configuration exceeded
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [String,nil] step_name Name of step in user flow where rate limit occurred
  # @identity.idp.previous_event_name Throttler Rate Limit Triggered
  def rate_limit_reached(
    limiter_type:,
    country_code: nil,
    phone_fingerprint: nil,
    context: nil,
    otp_delivery_preference: nil,
    step_name: nil,
    **extra
  )
    track_event(
      'Rate Limit Reached',
      limiter_type:,
      country_code:,
      phone_fingerprint:,
      context:,
      otp_delivery_preference:,
      step_name:,
      **extra,
    )
  end

  # Rate limit triggered
  # @param [String] type
  def rate_limit_triggered(type:, **extra)
    track_event('Rate Limit Triggered', type: type, **extra)
  end

  # Account profile reactivation submitted
  def reactivate_account_submit
    track_event('Reactivate Account Submitted')
  end

  # Submission event for the "verify password" page the user sees after entering their personal key.
  # @param [Boolean] success Whether the form was submitted successfully.
  def reactivate_account_verify_password_submitted(success:, **extra)
    track_event(:reactivate_account_verify_password_submitted, success: success, **extra)
  end

  # Visit event for the "verify password" page the user sees after entering their personal key.
  def reactivate_account_verify_password_visited(**extra)
    track_event(:reactivate_account_verify_password_visited, **extra)
  end

  # Account profile reactivation page visited
  def reactivate_account_visit
    track_event('Reactivate Account Visited')
  end

  # The result of a reCAPTCHA verification request was received
  # @param [Hash] recaptcha_result Full reCAPTCHA response body
  # @param [Float] score_threshold Minimum value for considering passing result
  # @param [Boolean] evaluated_as_valid Whether result was considered valid
  # @param [String] form_class Class name of form
  # @param [String, nil] exception_class Class name of exception, if error occurred
  # @param [String] recaptcha_action reCAPTCHA action name, for distinct user flow
  # @param [String, nil] phone_country_code Country code associated with reCAPTCHA phone results
  def recaptcha_verify_result_received(
    recaptcha_result:,
    score_threshold:,
    evaluated_as_valid:,
    form_class:,
    exception_class:,
    recaptcha_action:,
    phone_country_code: nil,
    **extra
  )
    track_event(
      'reCAPTCHA verify result received',
      recaptcha_result:,
      score_threshold:,
      evaluated_as_valid:,
      form_class:,
      exception_class:,
      recaptcha_action:,
      phone_country_code:,
      **extra,
    )
  end

  # User authenticated by a remembered device
  # @param [DateTime] cookie_created_at time the remember device cookie was created
  # @param [Integer] cookie_age_seconds age of the cookie in seconds
  def remembered_device_used_for_authentication(
    cookie_created_at:,
    cookie_age_seconds:,
    **extra
  )
    track_event(
      'Remembered device used for authentication',
      cookie_created_at: cookie_created_at,
      cookie_age_seconds: cookie_age_seconds,
      **extra,
    )
  end

  # Service provider completed remote logout
  # @param [String] service_provider
  # @param [String] user_id
  def remote_logout_completed(
    service_provider:,
    user_id:,
    **extra
  )
    track_event(
      'Remote Logout completed',
      service_provider: service_provider,
      user_id: user_id,
      **extra,
    )
  end

  # Service provider initiated remote logout
  # @param [String] service_provider
  # @param [Boolean] saml_request_valid
  def remote_logout_initiated(
    service_provider:,
    saml_request_valid:,
    **extra
  )
    track_event(
      'Remote Logout initiated',
      service_provider: service_provider,
      saml_request_valid: saml_request_valid,
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

  # A response timed out
  # @param [String] backtrace
  # @param [String] exception_message
  # @param [String] exception_class
  def response_timed_out(
    backtrace:,
    exception_message:,
    exception_class:,
    **extra
  )
    track_event(
      'Response Timed Out',
      backtrace: backtrace,
      exception_message: exception_message,
      exception_class: exception_class,
      **extra,
    )
  end

  # User cancelled the process and returned to the sp
  # @param [String] redirect_url the url of the service provider
  # @param [String] flow
  # @param [String] step
  # @param [String] location
  def return_to_sp_cancelled(
    redirect_url:,
    step: nil,
    location: nil,
    flow: nil,
    **extra
  )
    track_event(
      'Return to SP: Cancelled',
      redirect_url: redirect_url,
      step: step,
      location: location,
      flow: flow,
      **extra,
    )
  end

  # Tracks when a user is redirected back to the service provider after failing to proof.
  # @param [String] redirect_url the url of the service provider
  # @param [String] flow
  # @param [String] step
  # @param [String] location
  def return_to_sp_failure_to_proof(redirect_url:, flow: nil, step: nil, location: nil, **extra)
    track_event(
      'Return to SP: Failed to proof',
      redirect_url: redirect_url,
      flow: flow,
      step: step,
      location: location,
      **extra,
    )
  end

  # Tracks when risc security event is pushed
  # @param [String] client_id
  # @param [String] event_type
  # @param [Boolean] success
  # @param [Integer] status
  # @param [String] error
  def risc_security_event_pushed(
    client_id:,
    event_type:,
    success:,
    status: nil,
    error: nil,
    **extra
  )
    track_event(
      :risc_security_event_pushed,
      client_id:,
      error:,
      event_type:,
      status:,
      success:,
      **extra,
    )
  end

  # Tracks when rules of use is submitted with a success or failure
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  def rules_of_use_submitted(success:, errors:, error_details: nil, **extra)
    track_event(
      'Rules of Use Submitted',
      success:,
      errors:,
      error_details:,
      **extra,
    )
  end

  # Tracks when rules of use is visited
  def rules_of_use_visit
    track_event('Rules of Use Visited')
  end

  # Record SAML authentication payload Hash
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] nameid_format The NameID format sent in the response
  # @param [String] requested_nameid_format The NameID format requested
  # @param [Array] authn_context
  # @param [String] authn_context_comparison
  # @param [String] service_provider
  # @param [String] endpoint
  # @param [Boolean] idv
  # @param [Boolean] finish_profile
  # @param [String] requested_ial
  # @param [Boolean] request_signed
  # @param [String] matching_cert_serial matches the request certificate in a successful, signed
  #   request
  # @param [Boolean] certs_different Whether the matching cert changes when SHA256 validations
  #   are turned on in the saml_idp gem
  # @param [Hash] cert_error_details Details for errors that occurred because of an invalid
  #   signature
  # @param [String] sha256_matching_cert serial of the cert that matches when sha256 validations
  #   are turned on
  # @param [String] unknown_authn_contexts space separated list of unknown contexts
  def saml_auth(
    success:,
    errors:,
    nameid_format:,
    requested_nameid_format:,
    authn_context:,
    authn_context_comparison:,
    service_provider:,
    endpoint:,
    idv:,
    finish_profile:,
    requested_ial:,
    request_signed:,
    matching_cert_serial:,
    error_details: nil,
    cert_error_details: nil,
    certs_different: nil,
    sha256_matching_cert: nil,
    unknown_authn_contexts: nil,
    **extra
  )
    track_event(
      'SAML Auth',
      success:,
      errors:,
      error_details:,
      nameid_format:,
      requested_nameid_format:,
      authn_context:,
      authn_context_comparison:,
      service_provider:,
      endpoint:,
      idv:,
      finish_profile:,
      requested_ial:,
      request_signed:,
      matching_cert_serial:,
      cert_error_details:,
      certs_different:,
      sha256_matching_cert:,
      unknown_authn_contexts:,
      **extra,
    )
  end

  # @param [String] requested_ial
  # @param [Array] authn_context
  # @param [String, nil] requested_aal_authn_context
  # @param [String, nil] requested_vtr_authn_contexts
  # @param [Boolean] force_authn
  # @param [Boolean] final_auth_request
  # @param [String] service_provider
  # @param [Boolean] request_signed
  # @param [String] matching_cert_serial
  # @param [String] unknown_authn_contexts space separated list of unknown contexts
  # @param [Boolean] user_fully_authenticated
  # An external request for SAML Authentication was received
  def saml_auth_request(
    requested_ial:,
    authn_context:,
    requested_aal_authn_context:,
    requested_vtr_authn_contexts:,
    force_authn:,
    final_auth_request:,
    service_provider:,
    request_signed:,
    matching_cert_serial:,
    unknown_authn_contexts:,
    user_fully_authenticated:,
    **extra
  )
    track_event(
      'SAML Auth Request',
      requested_ial:,
      authn_context:,
      requested_aal_authn_context:,
      requested_vtr_authn_contexts:,
      force_authn:,
      final_auth_request:,
      service_provider:,
      request_signed:,
      matching_cert_serial:,
      unknown_authn_contexts:,
      user_fully_authenticated:,
      **extra,
    )
  end

  # User dismissed the second MFA reminder page
  # @param [Boolean] opted_to_add Whether the user chose to add a method
  def second_mfa_reminder_dismissed(opted_to_add:, **extra)
    track_event('Second MFA Reminder Dismissed', opted_to_add:, **extra)
  end

  # User visited the second MFA reminder page
  def second_mfa_reminder_visit
    track_event('Second MFA Reminder Visited')
  end

  # Tracks when security event is received
  # @param [Boolean] success Whether form validation was successful
  # @param [String] error_code
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] jti
  # @param [String] user_id
  # @param [String] client_id
  # @param [String] event_type
  def security_event_received(
    success:,
    errors:,
    event_type:,
    error_code: nil,
    error_details: nil,
    jti: nil,
    user_id: nil,
    client_id: nil,
    **extra
  )
    track_event(
      'RISC: Security event received',
      success:,
      errors:,
      error_details:,
      event_type:,
      error_code:,
      jti:,
      user_id:,
      client_id:,
      **extra,
    )
  end

  # Tracks if the session is kept alive
  def session_kept_alive
    track_event('Session Kept Alive')
  end

  # Tracks if the session timed out
  def session_timed_out
    track_event('Session Timed Out')
  end

  # Tracks when a user's session is timed out
  def session_total_duration_timeout
    track_event('User Maximum Session Length Exceeded')
  end

  # User events missing sign_in_notification_timeframe_expired
  def sign_in_notification_timeframe_expired_absent
    track_event(:sign_in_notification_timeframe_expired_absent)
  end

  # @param [String] flash
  # Tracks when a user visits the sign in page
  def sign_in_page_visit(flash:, **extra)
    track_event('Sign in page visited', flash:, **extra)
  end

  # User lands on security check failed page
  def sign_in_security_check_failed_visited
    track_event(:sign_in_security_check_failed_visited)
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Boolean] new_user Whether this is an incomplete user (no associated MFA methods)
  # @param [Boolean] has_other_auth_methods Whether the user has other authentication methods
  # @param [Integer] phone_configuration_id Phone configuration associated with request
  # Tracks when a user opts into SMS
  def sms_opt_in_submitted(
    success:,
    errors:,
    new_user:,
    has_other_auth_methods:,
    phone_configuration_id:,
    error_details: nil,
    **extra
  )
    track_event(
      'SMS Opt-In: Submitted',
      success:,
      errors:,
      error_details:,
      new_user:,
      has_other_auth_methods:,
      phone_configuration_id:,
      **extra,
    )
  end

  # @param [Boolean] new_user
  # @param [Boolean] has_other_auth_methods
  # @param [Integer] phone_configuration_id
  # Tracks when a user visits the sms opt in page
  def sms_opt_in_visit(
    new_user:,
    has_other_auth_methods:,
    phone_configuration_id:,
    **extra
  )
    track_event(
      'SMS Opt-In: Visited',
      new_user: new_user,
      has_other_auth_methods: has_other_auth_methods,
      phone_configuration_id: phone_configuration_id,
      **extra,
    )
  end

  # Tracks when a user is bounced back from the service provider due to an integration issue.
  def sp_handoff_bounced_detected
    track_event('SP handoff bounced detected')
  end

  # Tracks when a user visits the bounced page.
  def sp_handoff_bounced_visit
    track_event('SP handoff bounced visited')
  end

  # Tracks when a user visits the "This agency no longer uses Login.gov" page.
  def sp_inactive_visit
    track_event('SP inactive visited')
  end

  # @param [Array] error_details Full messages of the errors
  # @param [Hash] error_types Types of errors that are surfaced
  # @param [Symbol] event What part of the workflow the error occured in
  # @param [Boolean] integration_exists Whether the requesting issuer maps to an SP
  # @param [String] request_issuer The issuer in the request
  # Monitoring service-provider specific integration errors
  def sp_integration_errors_present(
    error_details:,
    error_types:,
    event:,
    integration_exists:,
    request_issuer: nil,
    **extra
  )
    types = error_types.index_with { |_type| true }
    track_event(
      :sp_integration_errors_present,
      error_details:,
      error_types: types,
      event:,
      integration_exists:,
      request_issuer:,
      **extra,
    )
  end

  # Tracks when a user is redirected back to the service provider
  # @param [Integer] ial
  # @param [Integer] billed_ial
  # @param [String, nil] sign_in_flow
  # @param [String, nil] vtr
  # @param [String, nil] acr_values
  # @param [Integer] sign_in_duration_seconds
  def sp_redirect_initiated(
    ial:,
    billed_ial:,
    sign_in_flow:,
    vtr:,
    acr_values:,
    sign_in_duration_seconds:,
    **extra
  )
    track_event(
      'SP redirect initiated',
      ial:,
      billed_ial:,
      sign_in_flow:,
      vtr: vtr,
      acr_values: acr_values,
      sign_in_duration_seconds:,
      **extra,
    )
  end

  # Tracks when service provider consent is revoked
  # @param [String] issuer issuer of the service provider consent to be revoked
  def sp_revoke_consent_revoked(issuer:, **extra)
    track_event(
      'SP Revoke Consent: Revoked',
      issuer: issuer,
      **extra,
    )
  end

  # Tracks when the page to revoke consent (unlink from) a service provider visited
  # @param [String] issuer which issuer
  def sp_revoke_consent_visited(issuer:, **extra)
    track_event(
      'SP Revoke Consent: Visited',
      issuer: issuer,
      **extra,
    )
  end

  # User submitted form to change email shared with service provider
  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] selected_email_id Selected email address record ID
  # @param [String, nil] needs_completion_screen_reason Reason for the consent screen being shown,
  #   if user is changing email in consent flow
  def sp_select_email_submitted(
    success:,
    selected_email_id:,
    error_details: nil,
    needs_completion_screen_reason: nil,
    **extra
  )
    track_event(
      :sp_select_email_submitted,
      success:,
      error_details:,
      needs_completion_screen_reason:,
      selected_email_id:,
      **extra,
    )
  end

  # User visited form to change email shared with service provider
  # @param [String, nil] needs_completion_screen_reason Reason for the consent screen being shown,
  #   if user is changing email in consent flow
  def sp_select_email_visited(needs_completion_screen_reason: nil, **extra)
    track_event(:sp_select_email_visited, needs_completion_screen_reason:, **extra)
  end

  # @param [String] area_code Area code of phone number
  # @param [String] country_code Abbreviated 2-letter country code associated with phone number
  # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
  # @param ["authentication", "reauthentication", "confirmation"] context User session context
  # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
  # @param [Boolean] resend
  # @param [Hash] telephony_response Response from Telephony gem
  # @param [:test, :pinpoint] adapter which adapter the OTP was delivered with
  # @param [Boolean] success
  # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
  # A phone one-time password send was attempted
  def telephony_otp_sent(
    area_code:,
    country_code:,
    phone_fingerprint:,
    context:,
    otp_delivery_preference:,
    resend:,
    telephony_response:,
    adapter:,
    success:,
    recaptcha_annotation: nil,
    **extra
  )
    track_event(
      'Telephony: OTP sent',
      {
        area_code: area_code,
        country_code: country_code,
        phone_fingerprint: phone_fingerprint,
        context: context,
        otp_delivery_preference: otp_delivery_preference,
        resend: resend,
        telephony_response: telephony_response,
        adapter: adapter,
        success: success,
        recaptcha_annotation:,
        **extra,
      },
    )
  end

  # Tracks when a user visits TOTP device setup
  # @param [Boolean] user_signed_up
  # @param [Boolean] totp_secret_present
  # @param [Integer] enabled_mfa_methods_count
  # @param [Boolean] in_account_creation_flow Whether user is going through account creation
  def totp_setup_visit(
    user_signed_up:,
    totp_secret_present:,
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    **extra
  )
    track_event(
      'TOTP Setup Visited',
      user_signed_up:,
      totp_secret_present:,
      enabled_mfa_methods_count:,
      in_account_creation_flow:,
      **extra,
    )
  end

  # @param [String] controller
  # @param [String] referer
  # @param [Boolean] user_signed_in
  # Redirect was almost sent to an invalid external host unexpectedly
  def unsafe_redirect_error(
    controller:,
    referer:,
    user_signed_in: nil,
    **extra
  )
    track_event(
      'Unsafe Redirect',
      controller: controller,
      referer: referer,
      user_signed_in: user_signed_in,
      **extra,
    )
  end

  # User has attempted to access an action that requires re-authenticating
  # @param [String] auth_method
  # @param [String] authenticated_at
  def user_2fa_reauthentication_required(auth_method:, authenticated_at:, **extra)
    track_event(
      'User 2FA Reauthentication Required',
      auth_method: auth_method,
      authenticated_at: authenticated_at,
      **extra,
    )
  end

  # User has been marked as authenticated
  # @param [String] authentication_type
  def user_marked_authed(authentication_type:, **extra)
    track_event(
      'User marked authenticated',
      authentication_type: authentication_type,
      **extra,
    )
  end

  # @param [Boolean] success Whether form validation was successful
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [Integer] enabled_mfa_methods_count
  # @param [Integer] selected_mfa_count
  # @param ['voice', 'auth_app'] selection
  # Tracks when the the user has selected and submitted MFA auth methods on user registration
  def user_registration_2fa_setup(
    success:,
    errors:,
    error_details: nil,
    selected_mfa_count: nil,
    enabled_mfa_methods_count: nil,
    selection: nil,
    **extra
  )
    track_event(
      'User Registration: 2FA Setup',
      success:,
      errors:,
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
  # @param [Hash] errors Errors resulting from form validation
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # @param [String] user_id ID of user associated with existing user, or current user
  # @param [Boolean] email_already_exists Whether an account with the email address already exists
  # @param [String] domain_name Domain name of email address submitted
  # @param [String] email_language Preferred language for email communication
  def user_registration_email(
    success:,
    rate_limited:,
    errors:,
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
      errors:,
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
    errors:,
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

  # Tracks when USPS in-person proofing enrollment is created
  # @param [String] enrollment_code
  # @param [Integer] enrollment_id
  # @param [Boolean] second_address_line_present
  # @param [String] service_provider
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # @param [String] tmx_status the tmx_status of the enrollment profile profile
  # @param [Boolean] enhanced_ipp Whether enrollment is for enhanced in-person proofing
  def usps_ippaas_enrollment_created(
    enrollment_code:,
    enrollment_id:,
    second_address_line_present:,
    service_provider:,
    opted_in_to_in_person_proofing:,
    tmx_status:,
    enhanced_ipp:,
    **extra
  )
    track_event(
      'USPS IPPaaS enrollment created',
      enrollment_code:,
      enrollment_id:,
      second_address_line_present:,
      service_provider:,
      opted_in_to_in_person_proofing:,
      tmx_status:,
      enhanced_ipp:,
      **extra,
    )
  end

  # @param [Hash] vendor_status
  # @param [String,nil] redirect_from
  # Tracks when vendor has outage
  def vendor_outage(
    vendor_status:,
    redirect_from: nil,
    **extra
  )
    track_event(
      'Vendor Outage',
      redirect_from: redirect_from,
      vendor_status: vendor_status,
      **extra,
    )
  end

  # @param [Boolean] success Whether the submission was successful
  # @param [Integer] configuration_id Database ID for the configuration
  # @param [Boolean] platform_authenticator Whether the configuration was a platform authenticator
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # Tracks when user attempts to delete a WebAuthn configuration
  # @identity.idp.previous_event_name WebAuthn Deleted
  def webauthn_delete_submitted(
    success:,
    configuration_id:,
    platform_authenticator:,
    error_details: nil,
    **extra
  )
    track_event(
      :webauthn_delete_submitted,
      success:,
      configuration_id:,
      platform_authenticator:,
      error_details:,
      **extra,
    )
  end

  # User submits WebAuthn platform authenticator recommended screen
  # @param [Boolean] opted_to_add Whether the user chose to add a method
  def webauthn_platform_recommended_submitted(opted_to_add:, **extra)
    track_event(:webauthn_platform_recommended_submitted, opted_to_add:, **extra)
  end

  # User visits WebAuthn platform authenticator recommended screen
  def webauthn_platform_recommended_visited
    track_event(:webauthn_platform_recommended_visited)
  end

  # @param [Hash] platform_authenticator
  # @param [Boolean] success
  # @param [Hash, nil] errors
  # @param [Boolean] in_account_creation_flow Whether user is going through account creation flow
  # Tracks whether or not Webauthn setup was successful
  def webauthn_setup_submitted(
    platform_authenticator:,
    success:,
    in_account_creation_flow: nil,
    errors: nil,
    **extra
  )
    track_event(
      :webauthn_setup_submitted,
      platform_authenticator: platform_authenticator,
      success: success,
      in_account_creation_flow:,
      errors: errors,
      **extra,
    )
  end

  # @param [Boolean] platform_authenticator Whether setup is for platform authenticator
  # @param [Integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
  # @param [Boolean] in_account_creation_flow Whether user is going through creation flow
  # Tracks when WebAuthn setup is visited
  def webauthn_setup_visit(
    platform_authenticator:,
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    **extra
  )
    track_event(
      'WebAuthn Setup Visited',
      platform_authenticator:,
      enabled_mfa_methods_count:,
      in_account_creation_flow:,
      **extra,
    )
  end

  # @param [Boolean] success Whether the submission was successful
  # @param [Integer] configuration_id Database ID for the configuration
  # @param [Boolean] platform_authenticator Whether the configuration was a platform authenticator
  # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
  # Tracks when user submits a name change for a WebAuthn configuration
  def webauthn_update_name_submitted(
    success:,
    configuration_id:,
    platform_authenticator:,
    error_details: nil,
    **extra
  )
    track_event(
      :webauthn_update_name_submitted,
      success:,
      platform_authenticator:,
      configuration_id:,
      error_details:,
      **extra,
    )
  end
end
