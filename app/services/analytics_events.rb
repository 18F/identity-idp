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
  # @param [String] user_id
  # @param [String, nil] message_id from AWS Pinpoint API
  # @param [String, nil] request_id from AWS Pinpoint API
  # An account reset was cancelled
  def account_reset_cancel(user_id:, message_id: nil, request_id: nil, **extra)
    track_event(
      'Account Reset: cancel',
      {
        user_id: user_id,
        message_id: message_id,
        request_id: request_id,
        **extra,
      }.compact,
    )
  end

  # @identity.idp.previous_event_name Account Reset
  # @param [String] user_id
  # @param [Hash] errors
  # Validates the token used for cancelling an account reset
  def account_reset_cancel_token_validation(user_id:, errors: nil, **extra)
    track_event(
      'Account Reset: cancel token validation',
      user_id: user_id,
      errors: errors,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account Reset
  # @param [Boolean] success
  # @param [String] user_id
  # @param [Integer, nil] account_age_in_days number of days since the account was confirmed
  # @param [Time] account_confirmed_at date that account creation was confirmed
  # (rounded) or nil if the account was not confirmed
  # @param [Hash] mfa_method_counts
  # @param [Hash] errors
  # An account has been deleted through the account reset flow
  def account_reset_delete(
    success:,
    user_id:,
    account_age_in_days:,
    account_confirmed_at:,
    mfa_method_counts:,
    errors: nil,
    **extra
  )
    track_event(
      'Account Reset: delete',
      success: success,
      user_id: user_id,
      account_age_in_days: account_age_in_days,
      account_confirmed_at: account_confirmed_at,
      mfa_method_counts: mfa_method_counts,
      errors: errors,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account Reset
  # @param [String] user_id
  # @param [Hash] errors
  # Validates the granted token for account reset
  def account_reset_granted_token_validation(user_id: nil, errors: nil, **extra)
    track_event(
      'Account Reset: granted token validation',
      user_id: user_id,
      errors: errors,
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
      {
        success: success,
        sms_phone: sms_phone,
        totp: totp,
        piv_cac: piv_cac,
        email_addresses: email_addresses,
        request_id: request_id,
        message_id: message_id,
        **extra,
      }.compact,
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

  # @param [Boolean] success
  # @param [String] user_id account the email is linked to
  # A user has clicked the confirmation link in an email
  def add_email_confirmation(user_id:, success: nil, **extra)
    track_event('Add Email: Email Confirmation', user_id: user_id, success: success, **extra)
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # Tracks request for adding new emails to an account
  def add_email_request(success:, errors:, **extra)
    track_event(
      'Add Email Requested',
      success: success,
      errors: errors,
      **extra,
    )
  end

  # When a user views the add email address page
  def add_email_visit
    track_event('Add Email Address Page Visited')
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
  # @param [Hash] error_details
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
  # @param [Hash] error_details
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
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  def backup_code_created(enabled_mfa_methods_count:, **extra)
    track_event(
      'Backup Code Created',
      enabled_mfa_methods_count: enabled_mfa_methods_count,
      **extra,
    )
  end

  # Tracks when the user visits the Backup Code Regenerate page.
  # @param [Boolean] in_account_creation_flow whether user is going through creation flow
  def backup_code_regenerate_visit(in_account_creation_flow:, **extra)
    track_event('Backup Code Regenerate Visited', in_account_creation_flow:, **extra)
  end

  # Track user creating new BackupCodeSetupForm, record form submission Hash
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Hash] error_details
  def backup_code_setup_visit(
    success:,
    errors: nil,
    error_details: nil,
    **extra
  )
    track_event(
      'Backup Code Setup Visited',
      success: success,
      errors: errors,
      error_details: error_details,
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

  # User was logged out due to an existing active session
  def concurrent_session_logout
    track_event(:concurrent_session_logout)
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

  # @param [String] message the warning
  # Logged when there is a non-user-facing error in the doc auth process, such as an unrecognized
  # field from a vendor
  def doc_auth_warning(message: nil, **extra)
    track_event(
      'Doc Auth Warning',
      message: message,
      **extra,
    )
  end

  # When a user views the edit password page
  def edit_password_visit
    track_event('Edit Password Page Visited')
  end

  # @param [Boolean] success
  # @param [String] user_id
  # @param [Boolean] user_locked_out if the user is currently locked out of their second factor
  # @param [String] bad_password_count represents number of prior login failures
  # @param [Boolean] sp_request_url_present if was an SP request URL in the session
  # @param [Boolean] remember_device if the remember device cookie was present
  # Tracks authentication attempts at the email/password screen
  def email_and_password_auth(
    success:,
    user_id:,
    user_locked_out:,
    bad_password_count:,
    sp_request_url_present:,
    remember_device:,
    **extra
  )
    track_event(
      'Email and Password Authentication',
      success: success,
      user_id: user_id,
      user_locked_out: user_locked_out,
      bad_password_count: bad_password_count,
      sp_request_url_present: sp_request_url_present,
      remember_device: remember_device,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # Tracks request for deletion of email address
  def email_deletion_request(success:, errors:, **extra)
    track_event(
      'Email Deletion Requested',
      success: success,
      errors: errors,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # Tracks if Email Language is updated
  def email_language_updated(success:, errors:, **extra)
    track_event(
      'Email Language: Updated',
      success: success,
      errors: errors,
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
  # @param [Hash] errors
  # @param [Time, nil] event_created_at timestamp for the event
  # @param [Time, nil] disavowed_device_last_used_at
  # @param [String, nil] disavowed_device_user_agent
  # @param [String, nil] disavowed_device_last_ip
  # @param [Integer, nil] event_id events table id
  # @param [String, nil] event_type (see Event#event_type)
  # @param [String, nil] event_ip ip address for the event
  # Tracks disavowed event
  def event_disavowal(
    success:,
    errors:,
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
      success: success,
      errors: errors,
      event_created_at: event_created_at,
      disavowed_device_last_used_at: disavowed_device_last_used_at,
      disavowed_device_user_agent: disavowed_device_user_agent,
      disavowed_device_last_ip: disavowed_device_last_ip,
      event_id: event_id,
      event_type: event_type,
      event_ip: event_ip,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Time, nil] event_created_at timestamp for the event
  # @param [Time, nil] disavowed_device_last_used_at
  # @param [String, nil] disavowed_device_user_agent
  # @param [String, nil] disavowed_device_last_ip
  # @param [Integer, nil] event_id events table id
  # @param [String, nil] event_type (see Event#event_type)
  # @param [String, nil] event_ip ip address for the event
  # Event disavowal password reset was performed
  def event_disavowal_password_reset(
    success:,
    errors:,
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
      success: success,
      errors: errors,
      event_created_at: event_created_at,
      disavowed_device_last_used_at: disavowed_device_last_used_at,
      disavowed_device_user_agent: disavowed_device_user_agent,
      disavowed_device_last_ip: disavowed_device_last_ip,
      event_id: event_id,
      event_type: event_type,
      event_ip: event_ip,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
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
      success: success,
      errors: errors,
      event_created_at: event_created_at,
      disavowed_device_last_used_at: disavowed_device_last_used_at,
      disavowed_device_user_agent: disavowed_device_user_agent,
      disavowed_device_last_ip: disavowed_device_last_ip,
      event_id: event_id,
      event_type: event_type,
      event_ip: event_ip,
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

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] exception
  # @param [String] profile_fraud_review_pending_at
  # The user was passed by manual fraud review
  def fraud_review_passed(
    success:,
    errors:,
    exception:,
    profile_fraud_review_pending_at:,
    **extra
  )
    track_event(
      'Fraud: Profile review passed',
      success: success,
      errors: errors,
      exception: exception,
      profile_fraud_review_pending_at: profile_fraud_review_pending_at,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] exception
  # @param [String] profile_fraud_review_pending_at
  # The user was rejected by manual fraud review
  def fraud_review_rejected(
    success:,
    errors:,
    exception:,
    profile_fraud_review_pending_at:,
    **extra
  )
    track_event(
      'Fraud: Profile review rejected',
      success: success,
      errors: errors,
      exception: exception,
      profile_fraud_review_pending_at: profile_fraud_review_pending_at,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] flow_path whether the user is in the hybrid or standard flow
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
    **_extra
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
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # @param [Boolean] success
  # @param [Boolean] address_edited
  # @param [Hash] pii_like_keypaths
  # @param [Hash] errors
  # @param [Hash] error_details
  # User submitted an idv address
  def idv_address_submitted(
    success:,
    errors:,
    address_edited: nil,
    pii_like_keypaths: nil,
    error_details: nil,
    **extra
  )
    track_event(
      'IdV: address submitted',
      success: success,
      errors: errors,
      address_edited: address_edited,
      pii_like_keypaths: pii_like_keypaths,
      error_details: error_details,
      **extra,
    )
  end

  # User visited idv address page
  def idv_address_visit
    track_event('IdV: address visited')
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
    **_extra
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
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] flow_path whether the user is in the hybrid or standard flow
  # @param [Boolean] isDrop
  # @param [Boolean] source
  # @param [Boolean] use_alternate_sdk
  # @param [String] liveness_checking_required Whether or not the selfie is required
  def idv_back_image_clicked(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    isDrop:,
    source:,
    use_alternate_sdk:,
    liveness_checking_required:,
    **_extra
  )
    track_event(
      'Frontend: IdV: back image clicked',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      isDrop: isDrop,
      source: source,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # @param [String] liveness_checking_required Whether or not the selfie is required
  def idv_barcode_warning_continue_clicked(liveness_checking_required:, **_extra)
    track_event(
      'Frontend: IdV: barcode warning continue clicked',
      liveness_checking_required: liveness_checking_required,
    )
  end

  # @param [String] liveness_checking_required Whether or not the selfie is required
  def idv_barcode_warning_retake_photos_clicked(liveness_checking_required:, **_extra)
    track_event(
      'Frontend: IdV: barcode warning retake photos clicked',
      liveness_checking_required: liveness_checking_required,
    )
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user confirmed their choice to cancel going through IDV
  def idv_cancellation_confirmed(step:, proofing_components: nil, **extra)
    track_event(
      'IdV: cancellation confirmed',
      step: step,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user chose to go back instead of cancel IDV
  def idv_cancellation_go_back(step:, proofing_components: nil, **extra)
    track_event(
      'IdV: cancellation go back',
      step: step,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # @param [String] request_came_from the controller and action from the
  #   source such as "users/sessions#new"
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user clicked cancel during IDV (presented with an option to go back or confirm)
  def idv_cancellation_visited(
    step:,
    request_came_from:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: cancellation visited',
      step: step,
      request_came_from: request_came_from,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] flow_path whether the user is in the hybrid or standard flow
  # @param [String] use_alternate_sdk
  # @param [Boolean] liveness_checking_required
  def idv_capture_troubleshooting_dismissed(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    use_alternate_sdk:,
    liveness_checking_required:,
    **_extra
  )
    track_event(
      'Frontend: IdV: Capture troubleshooting dismissed',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
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
  def idv_doc_auth_agreement_submitted(**extra)
    track_event('IdV: doc auth agreement submitted', **extra)
  end

  def idv_doc_auth_agreement_visited(**extra)
    track_event('IdV: doc auth agreement visited', **extra)
  end

  def idv_doc_auth_capture_complete_visited(**extra)
    track_event('IdV: doc auth capture_complete visited', **extra)
  end

  def idv_doc_auth_document_capture_submitted(**extra)
    track_event('IdV: doc auth document_capture submitted', **extra)
  end

  def idv_doc_auth_document_capture_visited(**extra)
    track_event('IdV: doc auth document_capture visited', **extra)
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
  def idv_doc_auth_failed_image_resubmitted(side:, **extra)
    track_event(
      'IdV: failed doc image resubmitted',
      side: side,
      **extra,
    )
  end

  def idv_doc_auth_how_to_verify_submitted(**extra)
    track_event(:idv_doc_auth_how_to_verify_submitted, **extra)
  end

  def idv_doc_auth_how_to_verify_visited(**extra)
    track_event(:idv_doc_auth_how_to_verify_visited, **extra)
  end

  # The "hybrid handoff" step: Desktop user has submitted their choice to
  # either continue via desktop ("document_capture" destination) or switch
  # to mobile phone ("send_link" destination) to perform document upload.
  # @identity.idp.previous_event_name IdV: doc auth upload submitted
  def idv_doc_auth_hybrid_handoff_submitted(**extra)
    track_event('IdV: doc auth hybrid handoff submitted', **extra)
  end

  # Desktop user has reached the above "hybrid handoff" view
  # @identity.idp.previous_event_name IdV: doc auth upload visited
  def idv_doc_auth_hybrid_handoff_visited(**extra)
    track_event('IdV: doc auth hybrid handoff visited', **extra)
  end

  # @identity.idp.previous_event_name IdV: doc auth send_link submitted
  def idv_doc_auth_link_sent_submitted(**extra)
    track_event('IdV: doc auth link_sent submitted', **extra)
  end

  def idv_doc_auth_link_sent_visited(**extra)
    track_event('IdV: doc auth link_sent visited', **extra)
  end

  def idv_doc_auth_randomizer_defaulted
    track_event(
      'IdV: doc_auth random vendor error',
      error: 'document_capture_session_uuid_key missing',
    )
  end

  def idv_doc_auth_redo_ssn_submitted(**extra)
    track_event('IdV: doc auth redo_ssn submitted', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing ssn submitted
  def idv_doc_auth_ssn_submitted(**extra)
    track_event('IdV: doc auth ssn submitted', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing ssn visited
  def idv_doc_auth_ssn_visited(**extra)
    track_event('IdV: doc auth ssn visited', **extra)
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Integer] submit_attempts (previously called "attempts")
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param [String] user_id
  # @param [String] flow_path
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [String] front_image_fingerprint Fingerprint of front image data
  # @param [String] back_image_fingerprint Fingerprint of back image data
  # The document capture image uploaded was locally validated during the IDV process
  def idv_doc_auth_submitted_image_upload_form(
    success:,
    errors:,
    remaining_submit_attempts:,
    flow_path:,
    liveness_checking_required:,
    submit_attempts: nil,
    user_id: nil,
    front_image_fingerprint: nil,
    back_image_fingerprint: nil,
    **extra
  )
    track_event(
      'IdV: doc auth image upload form submitted',
      success: success,
      errors: errors,
      submit_attempts: submit_attempts,
      remaining_submit_attempts: remaining_submit_attempts,
      user_id: user_id,
      flow_path: flow_path,
      front_image_fingerprint: front_image_fingerprint,
      back_image_fingerprint: back_image_fingerprint,
      liveness_checking_required: liveness_checking_required,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] exception
  # @param [Boolean] billed
  # @param [String] doc_auth_result
  # @param [String] state
  # @param [String] state_id_type
  # @param [Boolean] async
  # @param [Integer] submit_attempts (previously called "attempts")
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param [Hash] client_image_metrics
  # @param [String] flow_path
  # @param [Float] vendor_request_time_in_ms Time it took to upload images & get a response.
  # @param [String] front_image_fingerprint Fingerprint of front image data
  # @param [String] back_image_fingerprint Fingerprint of back image data
  # @param [Boolean] attention_with_barcode
  # @param [Boolean] doc_type_supported
  # @param [Boolean] doc_auth_success
  # @param [String] liveness_checking_required Whether or not the selfie is required
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
    billed: nil,
    doc_auth_result: nil,
    vendor_request_time_in_ms: nil,
    front_image_fingerprint: nil,
    back_image_fingerprint: nil,
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
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] user_id
  # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
  # @param [Hash] pii_like_keypaths
  # @param [String] flow_path
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [String] front_image_fingerprint Fingerprint of front image data
  # @param [String] back_image_fingerprint Fingerprint of back image data
  # @param [Hash] classification_info document image side information, issuing country and type etc
  # The PII that came back from the document capture vendor was validated
  def idv_doc_auth_submitted_pii_validation(
    success:,
    errors:,
    remaining_submit_attempts:,
    pii_like_keypaths:,
    flow_path:,
    liveness_checking_required:,
    user_id: nil,
    front_image_fingerprint: nil,
    back_image_fingerprint: nil,
    classification_info: {},
    **extra
  )
    track_event(
      'IdV: doc auth image upload vendor pii validation',
      success: success,
      errors: errors,
      user_id: user_id,
      remaining_submit_attempts: remaining_submit_attempts,
      pii_like_keypaths: pii_like_keypaths,
      flow_path: flow_path,
      front_image_fingerprint: front_image_fingerprint,
      back_image_fingerprint: back_image_fingerprint,
      classification_info: classification_info,
      liveness_checking_required: liveness_checking_required,
      **extra,
    )
  end

  def idv_doc_auth_verify_proofing_results(**extra)
    track_event('IdV: doc auth verify proofing results', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing verify submitted
  def idv_doc_auth_verify_submitted(**extra)
    track_event('IdV: doc auth verify submitted', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing verify visited
  def idv_doc_auth_verify_visited(**extra)
    track_event('IdV: doc auth verify visited', **extra)
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

  def idv_doc_auth_welcome_submitted(**extra)
    track_event('IdV: doc auth welcome submitted', **extra)
  end

  def idv_doc_auth_welcome_visited(**extra)
    track_event('IdV: doc auth welcome visited', **extra)
  end

  # User submitted IDV password confirm page
  # @param [Boolean] success
  # @param [Boolean] fraud_review_pending
  # @param [Boolean] fraud_rejection
  # @param [Boolean] gpo_verification_pending
  # @param [Boolean] in_person_verification_pending
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # @param [String, nil] deactivation_reason Reason user's profile was deactivated, if any.
  # @identity.idp.previous_event_name  IdV: review info visited
  def idv_enter_password_submitted(
    success:,
    fraud_review_pending:,
    fraud_rejection:,
    gpo_verification_pending:,
    in_person_verification_pending:,
    deactivation_reason: nil,
    proofing_components: nil,
    **extra
  )
    track_event(
      :idv_enter_password_submitted,
      success: success,
      deactivation_reason: deactivation_reason,
      fraud_review_pending: fraud_review_pending,
      gpo_verification_pending: gpo_verification_pending,
      in_person_verification_pending: in_person_verification_pending,
      fraud_rejection: fraud_rejection,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's
  #        current proofing components
  # @param [String] address_verification_method The method (phone or gpo) being
  #        used to verify the user's identity
  # User visited IDV password confirm page
  # @identity.idp.previous_event_name  IdV: review info visited
  def idv_enter_password_visited(
    proofing_components: nil,
    address_verification_method: nil,
    **extra
  )
    track_event(
      :idv_enter_password_visited,
      address_verification_method: address_verification_method,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] flow_path whether the user is in the hybrid or standard flow
  # @param [Array] ids ID Types the user has checked whether they have
  # @param [String] use_alternate_sdk
  # Exit survey of optional questions when the user leaves document capture
  def idv_exit_optional_questions(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    ids:,
    use_alternate_sdk:,
    **_extra
  )
    track_event(
      'Frontend: IdV: exit optional questions',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      ids: ids,
      use_alternate_sdk: use_alternate_sdk,
    )
  end

  # @param [Boolean] success
  # @param [String, nil] deactivation_reason Reason user's profile was deactivated, if any.
  # @param [Boolean] fraud_review_pending Profile is under review for fraud
  # @param [Boolean] fraud_rejection Profile is rejected due to fraud
  # @param [Boolean] gpo_verification_pending Profile is awaiting gpo verificaiton
  # @param [Boolean] in_person_verification_pending Profile is awaiting in person verificaiton
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # @see Reporting::IdentityVerificationReport#query This event is used by the identity verification
  #       report. Changes here should be reflected there.
  # Tracks the last step of IDV, indicates the user successfully proofed
  def idv_final(
    success:,
    fraud_review_pending:,
    fraud_rejection:,
    gpo_verification_pending:,
    in_person_verification_pending:,
    deactivation_reason: nil,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: final resolution',
      success: success,
      fraud_review_pending: fraud_review_pending,
      fraud_rejection: fraud_rejection,
      gpo_verification_pending: gpo_verification_pending,
      in_person_verification_pending: in_person_verification_pending,
      deactivation_reason: deactivation_reason,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User visited forgot password page
  def idv_forgot_password(proofing_components: nil, **extra)
    track_event(
      'IdV: forgot password visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User confirmed forgot password
  def idv_forgot_password_confirmed(proofing_components: nil, **extra)
    track_event(
      'IdV: forgot password confirmed',
      proofing_components: proofing_components,
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
    **_extra
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
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] flow_path whether the user is in the hybrid or standard flow
  # @param [Boolean] isDrop
  # @param [String] source
  # @param [String] use_alternate_sdk
  # @param [Boolean] liveness_checking_required
  def idv_front_image_clicked(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    isDrop:,
    source:,
    use_alternate_sdk:,
    liveness_checking_required: nil,
    **_extra
  )
    track_event(
      'Frontend: IdV: front image clicked',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      isDrop: isDrop,
      source: source,
      use_alternate_sdk: use_alternate_sdk,
      liveness_checking_required: liveness_checking_required,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # @param [DateTime] enqueued_at When letter was enqueued
  # @param [Boolean] resend User requested a second (or more) letter
  # @param [DateTime] first_letter_requested_at When the profile became gpo_pending
  # @param [Integer] hours_since_first_letter Difference between first_letter_requested_at
  #                  and now in hours
  # @param [Integer] phone_step_attempts Number of attempts at phone step before requesting letter
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # GPO letter was enqueued and the time at which it was enqueued
  def idv_gpo_address_letter_enqueued(
    enqueued_at:,
    resend:,
    first_letter_requested_at:,
    hours_since_first_letter:,
    phone_step_attempts:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: USPS address letter enqueued',
      enqueued_at: enqueued_at,
      resend: resend,
      first_letter_requested_at: first_letter_requested_at,
      hours_since_first_letter: hours_since_first_letter,
      phone_step_attempts: phone_step_attempts,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] resend
  # @param [DateTime] first_letter_requested_at When the profile became gpo_pending
  # @param [Integer] hours_since_first_letter Difference between first_letter_requested_at
  #                  and now in hours
  # @param [Integer] phone_step_attempts Number of attempts at phone step before requesting letter
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # GPO letter was requested
  def idv_gpo_address_letter_requested(
    resend:,
    first_letter_requested_at:,
    hours_since_first_letter:,
    phone_step_attempts:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: USPS address letter requested',
      resend: resend,
      first_letter_requested_at:,
      hours_since_first_letter:,
      phone_step_attempts:,
      proofing_components: proofing_components,
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
  # @param [String] flow_path
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
    **_extra
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
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

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
  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user submitted the in person proofing location step
  def idv_in_person_location_submitted(
    selected_location:,
    flow_path:,
    opted_in_to_in_person_proofing:,
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

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
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
  # @param [String] exception_class
  # @param [String] exception_message
  # @param [Boolean] response_body_present
  # @param [Hash] response_body
  # @param [Integer] response_status_code
  def idv_in_person_locations_request_failure(
    exception_class:,
    exception_message:,
    response_body_present:,
    response_body:,
    response_status_code:,
    **extra
  )
    track_event(
      'Request USPS IPP locations: request failed',
      exception_class: exception_class,
      exception_message: exception_message,
      response_body_present: response_body_present,
      response_body: response_body,
      response_status_code: response_status_code,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Integer] result_total
  # @param [String] errors
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

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
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

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
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

  # @param [String] flow_path
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] irs_reproofing
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # address page visited
  def idv_in_person_proofing_address_visited(
    flow_path: nil,
    step: nil,
    analytics_id: nil,
    irs_reproofing: nil,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing address visited',
      flow_path: flow_path,
      step: step,
      analytics_id: analytics_id,
      irs_reproofing: irs_reproofing,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      **extra,
    )
  end

  # @param [String] flow_path
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] irs_reproofing
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean] same_address_as_id
  # User clicked cancel on update state id page
  def idv_in_person_proofing_cancel_update_state_id(
    flow_path: nil,
    step: nil,
    analytics_id: nil,
    irs_reproofing: nil,
    success: nil,
    errors: nil,
    same_address_as_id: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing cancel_update_state_id submitted',
      flow_path: flow_path,
      step: step,
      analytics_id: analytics_id,
      irs_reproofing: irs_reproofing,
      success: success,
      errors: errors,
      same_address_as_id: same_address_as_id,
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

  # @param [String] flow_path
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] irs_reproofing
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean] same_address_as_id
  # User submitted state id on redo state id page
  def idv_in_person_proofing_redo_state_id_submitted(
    flow_path: nil,
    step: nil,
    analytics_id: nil,
    irs_reproofing: nil,
    success: nil,
    errors: nil,
    same_address_as_id: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing redo_state_id submitted',
      flow_path: flow_path,
      step: step,
      analytics_id: analytics_id,
      irs_reproofing: irs_reproofing,
      success: success,
      errors: errors,
      same_address_as_id: same_address_as_id,
      **extra,
    )
  end

  def idv_in_person_proofing_residential_address_submitted(**extra)
    track_event('IdV: in person proofing residential address submitted', **extra)
  end

  # @param [String] flow_path
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] irs_reproofing
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean, nil] same_address_as_id
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # User submitted state id
  def idv_in_person_proofing_state_id_submitted(
    flow_path: nil,
    step: nil,
    analytics_id: nil,
    irs_reproofing: nil,
    success: nil,
    errors: nil,
    same_address_as_id: nil,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing state_id submitted',
      flow_path: flow_path,
      step: step,
      analytics_id: analytics_id,
      irs_reproofing: irs_reproofing,
      success: success,
      errors: errors,
      same_address_as_id: same_address_as_id,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      **extra,
    )
  end

  # @param [String] flow_path
  # @param [String] step
  # @param [String] analytics_id
  # @param [Boolean] irs_reproofing
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # State id page visited
  def idv_in_person_proofing_state_id_visited(
    flow_path: nil,
    step: nil,
    analytics_id: nil,
    irs_reproofing: nil,
    opted_in_to_in_person_proofing: nil,
    **extra
  )
    track_event(
      'IdV: in person proofing state_id visited',
      flow_path: flow_path,
      step: step,
      analytics_id: analytics_id,
      irs_reproofing: irs_reproofing,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
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

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user visited the "ready to verify" page for the in person proofing flow
  def idv_in_person_ready_to_verify_visit(proofing_components: nil,
                                          **extra)
    track_event(
      'IdV: in person ready to verify visited',
      proofing_components: proofing_components,
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
  # @param [Hash] telephony_response response from Telephony gem
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

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user submitted the in person proofing switch_back step
  def idv_in_person_switch_back_submitted(flow_path:, **extra)
    track_event('IdV: in person proofing switch_back submitted', flow_path: flow_path, **extra)
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
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
  def idv_in_person_usps_proofing_results_job_completed(
    duration_seconds:,
    enrollments_checked:,
    enrollments_errored:,
    enrollments_expired:,
    enrollments_failed:,
    enrollments_in_progress:,
    enrollments_passed:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Job completed',
      duration_seconds: duration_seconds,
      enrollments_checked: enrollments_checked,
      enrollments_errored: enrollments_errored,
      enrollments_expired: enrollments_expired,
      enrollments_failed: enrollments_failed,
      enrollments_in_progress: enrollments_in_progress,
      enrollments_passed: enrollments_passed,
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
  # @param [String] enrollment_id
  def idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated(
    enrollment_id:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: deadline passed email initiated',
      enrollment_id: enrollment_id,
      **extra,
    )
  end

  # Tracks emails that are initiated during GetUspsProofingResultsJob
  # @param [String] email_type success, failed or failed fraud
  def idv_in_person_usps_proofing_results_job_email_initiated(
    email_type:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Success or failure email initiated',
      email_type: email_type,
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
  # @param [Boolean] fraud_suspected
  # @param [Boolean] passed did this enrollment pass or fail?
  # @param [String] reason why did this enrollment pass or fail?
  def idv_in_person_usps_proofing_results_job_enrollment_updated(
    enrollment_code:,
    enrollment_id:,
    minutes_since_established:,
    fraud_suspected:,
    passed:,
    reason:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Enrollment status updated',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      minutes_since_established: minutes_since_established,
      fraud_suspected: fraud_suspected,
      passed: passed,
      reason: reason,
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
  # @param [Integer] response_status_code
  def idv_in_person_usps_proofing_results_job_exception(
    reason:,
    enrollment_id:,
    minutes_since_established:,
    exception_class: nil,
    exception_message: nil,
    enrollment_code: nil,
    minutes_since_last_status_check: nil,
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
    response_message: nil,
    response_status_code: nil,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Exception raised',
      reason: reason,
      enrollment_id: enrollment_id,
      exception_class: exception_class,
      exception_message: exception_message,
      enrollment_code: enrollment_code,
      minutes_since_established: minutes_since_established,
      minutes_since_last_status_check: minutes_since_last_status_check,
      minutes_since_last_status_update: minutes_since_last_status_update,
      minutes_to_completion: minutes_to_completion,
      fraud_suspected: fraud_suspected,
      primary_id_type: primary_id_type,
      secondary_id_type: secondary_id_type,
      failure_reason: failure_reason,
      transaction_end_date_time: transaction_end_date_time,
      transaction_start_date_time: transaction_start_date_time,
      status: status,
      assurance_level: assurance_level,
      proofing_post_office: proofing_post_office,
      proofing_city: proofing_city,
      proofing_state: proofing_state,
      scan_count: scan_count,
      response_message: response_message,
      response_status_code: response_status_code,
      **extra,
    )
  end

  # Tracks please call emails that are initiated during GetUspsProofingResultsJob
  def idv_in_person_usps_proofing_results_job_please_call_email_initiated(
    **extra
  )
    track_event(
      :idv_in_person_usps_proofing_results_job_please_call_email_initiated,
      **extra,
    )
  end

  # GetUspsProofingResultsJob is beginning. Includes some metadata about what the job will do
  # @param [Integer] enrollments_count number of enrollments eligible for status check
  # @param [Integer] reprocess_delay_minutes minimum delay since last status check
  def idv_in_person_usps_proofing_results_job_started(
    enrollments_count:,
    reprocess_delay_minutes:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Job started',
      enrollments_count: enrollments_count,
      reprocess_delay_minutes: reprocess_delay_minutes,
      **extra,
    )
  end

  # Tracks unexpected responses from the USPS API
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [Float] minutes_since_established
  # @param [String] response_message
  # @param [String] reason why was this error unexpected?
  def idv_in_person_usps_proofing_results_job_unexpected_response(
    enrollment_code:,
    enrollment_id:,
    minutes_since_established:,
    response_message:,
    reason:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Unexpected response received',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      minutes_since_established: minutes_since_established,
      response_message: response_message,
      reason: reason,
      **extra,
    )
  end

  # A user has been moved to fraud review after completing proofing at the USPS
  # @param [String] enrollment_id
  def idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review(
    enrollment_id:,
    **extra
  )
    track_event(
      :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
      enrollment_id: enrollment_id,
      **extra,
    )
  end

  # Tracks if USPS in-person proofing enrollment request fails
  # @param [String] context
  # @param [String] reason
  # @param [Integer] enrollment_id
  # @param [String] exception_class
  # @param [String] exception_message
  def idv_in_person_usps_request_enroll_exception(
    context:,
    reason:,
    enrollment_id:,
    exception_class:,
    exception_message:,
    **extra
  )
    track_event(
      'USPS IPPaaS enrollment failed',
      context: context,
      enrollment_id: enrollment_id,
      exception_class: exception_class,
      exception_message: exception_message,
      reason: reason,
      **extra,
    )
  end

  # User visits IdV
  def idv_intro_visit
    track_event('IdV: intro visited')
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
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # @identity.idp.previous_event_name IdV: come back later visited
  def idv_letter_enqueued_visit(proofing_components: nil, **extra)
    track_event(
      'IdV: letter enqueued visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] isCancelled
  # @param [Boolean] isRateLimited
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_link_sent_capture_doc_polling_complete(
    isCancelled:,
    isRateLimited:,
    **_extra
  )
    track_event(
      'Frontend: IdV: Link sent capture doc polling complete',
      isCancelled: isCancelled,
      isRateLimited: isRateLimited,
    )
  end

  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  def idv_link_sent_capture_doc_polling_started(**_extra)
    track_event(
      'Frontend: IdV: Link sent capture doc polling started',
    )
  end

  # Tracks when the user visits Mail only warning when vendor_status_sms is set to full_outage
  def idv_mail_only_warning_visited(**extra)
    track_event(
      'IdV: Mail only warning visited',
      **extra,
    )
  end

  # Tracks whether the user's device appears to be mobile device with a camera attached.
  # @param [Boolean] is_camera_capable_mobile Whether we think the device _could_ have a camera.
  # @param [Boolean,nil] camera_present Whether the user's device _actually_ has a camera available.
  # @param [Integer,nil] grace_time Extra time allowed for browser to report camera availability.
  # @param [Integer,nil] duration Time taken for browser to report camera availability.
  def idv_mobile_device_and_camera_check(
    is_camera_capable_mobile:,
    camera_present: nil,
    grace_time: nil,
    duration: nil,
    **extra
  )
    track_event(
      'IdV: Mobile device and camera check',
      is_camera_capable_mobile: is_camera_capable_mobile,
      camera_present: camera_present,
      grace_time: grace_time,
      duration: duration,
      **extra,
    )
  end

  # @param [Integer] failed_capture_attempts Number of failed Acuant SDK attempts
  # @param [Integer] failed_submission_attempts Number of failed Acuant doc submissions
  # @param [String] field Image form field
  # @param [String] flow_path Document capture path ("hybrid" or "standard")
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
  def idv_not_verified_visited
    track_event('IdV: Not verified visited')
  end

  # Tracks if a user clicks the 'acknowledge' checkbox during personal
  # key creation
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # @param [boolean] checked whether the user checked or un-checked
  #                  the box with this click
  def idv_personal_key_acknowledgment_toggled(checked:, proofing_components:, **extra)
    track_event(
      'IdV: personal key acknowledgment toggled',
      checked: checked,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # A user has downloaded their personal key. This event is no longer emitted.
  # @identity.idp.previous_event_name IdV: download personal key
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  def idv_personal_key_downloaded(proofing_components: nil, **extra)
    track_event(
      'IdV: personal key downloaded',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # @param [String, nil] deactivation_reason Reason profile was deactivated.
  # @param [Boolean] fraud_review_pending Profile is under review for fraud
  # @param [Boolean] fraud_rejection Profile is rejected due to fraud
  # @param [Boolean] in_person_verification_pending Profile is pending in-person verification
  # User submitted IDV personal key page
  def idv_personal_key_submitted(
    fraud_review_pending:,
    fraud_rejection:,
    in_person_verification_pending:,
    proofing_components: nil,
    deactivation_reason: nil,
    **extra
  )
    track_event(
      'IdV: personal key submitted',
      in_person_verification_pending: in_person_verification_pending,
      deactivation_reason: deactivation_reason,
      fraud_review_pending: fraud_review_pending,
      fraud_rejection: fraud_rejection,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User visited IDV personal key page
  def idv_personal_key_visited(proofing_components: nil, **extra)
    track_event(
      'IdV: personal key visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param ["sms", "voice"] otp_delivery_preference
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user submitted their phone on the phone confirmation page
  def idv_phone_confirmation_form_submitted(
    success:,
    otp_delivery_preference:,
    errors:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation form',
      success: success,
      errors: errors,
      otp_delivery_preference: otp_delivery_preference,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user was rate limited for submitting too many OTPs during the IDV phone step
  def idv_phone_confirmation_otp_rate_limit_attempts(proofing_components: nil, **extra)
    track_event(
      'Idv: Phone OTP attempts rate limited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user was locked out for hitting the phone OTP rate limit during IDV
  def idv_phone_confirmation_otp_rate_limit_locked_out(proofing_components: nil, **extra)
    track_event(
      'Idv: Phone OTP rate limited user',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user was rate limited for requesting too many OTPs during the IDV phone step
  def idv_phone_confirmation_otp_rate_limit_sends(proofing_components: nil, **extra)
    track_event(
      'Idv: Phone OTP sends rate limited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param ["sms","voice"] otp_delivery_preference which channel the OTP was delivered by
  # @param [String] country_code country code of phone number
  # @param [String] area_code area code of phone number
  # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
  # @param [Hash] telephony_response response from Telephony gem
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user resent an OTP during the IDV phone step
  def idv_phone_confirmation_otp_resent(
    success:,
    errors:,
    otp_delivery_preference:,
    country_code:,
    area_code:,
    rate_limit_exceeded:,
    telephony_response:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation otp resent',
      success: success,
      errors: errors,
      otp_delivery_preference: otp_delivery_preference,
      country_code: country_code,
      area_code: area_code,
      rate_limit_exceeded: rate_limit_exceeded,
      telephony_response: telephony_response,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param ["sms","voice"] otp_delivery_preference which channel the OTP was delivered by
  # @param [String] country_code country code of phone number
  # @param [String] area_code area code of phone number
  # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
  # @param [String] phone_fingerprint the hmac fingerprint of the phone number formatted as e164
  # @param [Hash] telephony_response response from Telephony gem
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # @param [:test, :pinpoint] adapter which adapter the OTP was delivered with
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
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation otp sent',
      success: success,
      errors: errors,
      otp_delivery_preference: otp_delivery_preference,
      country_code: country_code,
      area_code: area_code,
      rate_limit_exceeded: rate_limit_exceeded,
      phone_fingerprint: phone_fingerprint,
      telephony_response: telephony_response,
      adapter: adapter,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean] code_expired if the one-time code expired
  # @param [Boolean] code_matches
  # @param [Integer] second_factor_attempts_count number of attempts to confirm this phone
  # @param [Time, nil] second_factor_locked_at timestamp when the phone was locked out
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # When a user attempts to confirm posession of a new phone number during the IDV process
  def idv_phone_confirmation_otp_submitted(
    success:,
    errors:,
    code_expired:,
    code_matches:,
    second_factor_attempts_count:,
    second_factor_locked_at:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation otp submitted',
      success: success,
      errors: errors,
      code_expired: code_expired,
      code_matches: code_matches,
      second_factor_attempts_count: second_factor_attempts_count,
      second_factor_locked_at: second_factor_locked_at,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # When a user visits the page to confirm posession of a new phone number during the IDV process
  def idv_phone_confirmation_otp_visit(proofing_components: nil, **extra)
    track_event(
      'IdV: phone confirmation otp visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The vendor finished the process of confirming the users phone
  def idv_phone_confirmation_vendor_submitted(
    success:,
    errors:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation vendor',
      success: success,
      errors: errors,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param ['warning','jobfail','failure'] type
  # @param [Time] limiter_expires_at when the rate limit expires
  # @param [Integer] remaining_submit_attempts number of submit attempts remaining
  #                  (previously called "remaining_attempts")
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # When a user gets an error during the phone finder flow of IDV
  def idv_phone_error_visited(
    type:,
    proofing_components: nil,
    limiter_expires_at: nil,
    remaining_submit_attempts: nil,
    **extra
  )
    track_event(
      'IdV: phone error visited',
      {
        type: type,
        proofing_components: proofing_components,
        limiter_expires_at: limiter_expires_at,
        remaining_submit_attempts: remaining_submit_attempts,
        **extra,
      }.compact,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User visited idv phone of record
  def idv_phone_of_record_visited(proofing_components: nil, **extra)
    track_event(
      'IdV: phone of record visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param ["sms", "voice"] otp_delivery_preference
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Hash] error_details
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  def idv_phone_otp_delivery_selection_submitted(
    success:,
    otp_delivery_preference:,
    proofing_components: nil,
    errors: nil,
    error_details: nil,
    **extra
  )
    track_event(
      'IdV: Phone OTP Delivery Selection Submitted',
      {
        success: success,
        errors: errors,
        error_details: error_details,
        otp_delivery_preference: otp_delivery_preference,
        proofing_components: proofing_components,
        **extra,
      }.compact,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User visited idv phone OTP delivery selection
  def idv_phone_otp_delivery_selection_visit(proofing_components: nil, **extra)
    track_event(
      'IdV: Phone OTP delivery Selection Visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
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
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # Tracks when the user reaches the verify please call page after failing proofing
  def idv_please_call_visited(proofing_components: nil, **extra)
    track_event(
      'IdV: Verify please call visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The system encountered an error and the proofing results are missing
  def idv_proofing_resolution_result_missing(proofing_components: nil, **extra)
    track_event(
      'IdV: proofing resolution result missing',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] letter_already_sent
  # GPO "request letter" page visited
  # @identity.idp.previous_event_name IdV: USPS address visited
  def idv_request_letter_visited(
    letter_already_sent:,
    **extra
  )
    track_event(
      'IdV: request letter visited',
      letter_already_sent: letter_already_sent,
      **extra,
    )
  end

  # User closed the SDK for taking a selfie without submitting a photo
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_sdk_selfie_image_capture_closed_without_photo(captureAttempts: nil, **extra)
    track_event(
      :idv_sdk_selfie_image_capture_closed_without_photo,
      captureAttempts: captureAttempts,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User encountered an error with the SDK selfie process
  #   Error code 1: camera permission not granted
  #   Error code 2: unexpected errors
  # @param [Integer] sdk_error_code SDK code for the error encountered
  # @param [String] sdk_error_message SDK message for the error encountered
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_sdk_selfie_image_capture_failed(
    sdk_error_code:,
    sdk_error_message:,
    captureAttempts: nil,
    **extra
  )
    track_event(
      :idv_sdk_selfie_image_capture_failed,
      sdk_error_code: sdk_error_code,
      sdk_error_message: sdk_error_message,
      captureAttempts: captureAttempts,
      **extra,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User opened the SDK to take a selfie
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_sdk_selfie_image_capture_opened(captureAttempts: nil, **extra)
    track_event(:idv_sdk_selfie_image_capture_opened, captureAttempts: captureAttempts, **extra)
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # User took a selfie image with the SDK, or uploaded a selfie using the file picker
  # @param [Integer] captureAttempts number of attempts to capture / upload an image
  #                  (previously called "attempt")
  # @param [Integer] failedImageResubmission
  # @param [String] fingerprint fingerprint of the image added
  # @param [String] flow_path whether the user is in the hybrid or standard flow
  # @param [Integer] height height of image added in pixels
  # @param [String] mimeType MIME type of image added
  # @param [Integer] size size of image added in bytes
  # @param [String] source
  # @param [String] liveness_checking_required Whether or not the selfie is required
  # @param [Integer] width width of image added in pixels
  # rubocop:disable Naming/VariableName,Naming/MethodParameterName
  def idv_selfie_image_added(
    captureAttempts:,
    failedImageResubmission:,
    fingerprint:,
    flow_path:,
    height:,
    mimeType:,
    size:,
    source:,
    liveness_checking_required:,
    width:,
    **_extra
  )
    track_event(
      :idv_selfie_image_added,
      captureAttempts: captureAttempts,
      failedImageResubmission: failedImageResubmission,
      fingerprint: fingerprint,
      flow_path: flow_path,
      height: height,
      mimeType: mimeType,
      size: size,
      source: source,
      liveness_checking_required: liveness_checking_required,
      width: width,
    )
  end
  # rubocop:enable Naming/VariableName,Naming/MethodParameterName

  # Tracks when the user visits one of the the session error pages.
  # @param [String] type
  # @param [Integer,nil] submit_attempts_remaining (previously called "attempts_remaining")
  def idv_session_error_visited(
    type:,
    submit_attempts_remaining: nil,
    **extra
  )
    track_event(
      'IdV: session error visited',
      type: type,
      submit_attempts_remaining: submit_attempts_remaining,
      **extra,
    )
  end

  # @param [String] step
  # @param [String] location
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User started over idv
  def idv_start_over(
    step:,
    location:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: start over',
      step: step,
      location: location,
      proofing_components: proofing_components,
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
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Hash] pii_like_keypaths
  # @param [DateTime] enqueued_at When was this letter enqueued
  # @param [Integer] which_letter Sorted by enqueue time, which letter had this code
  # @param [Integer] letter_count How many letters did the user enqueue for this profile
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
    pii_like_keypaths:,
    enqueued_at:,
    which_letter:,
    letter_count:,
    submit_attempts:,
    pending_in_person_enrollment:,
    fraud_check_failed:,
    **extra
  )
    track_event(
      'IdV: enter verify by mail code submitted',
      success: success,
      errors: errors,
      pii_like_keypaths: pii_like_keypaths,
      enqueued_at: enqueued_at,
      which_letter: which_letter,
      letter_count: letter_count,
      submit_attempts: submit_attempts,
      pending_in_person_enrollment: pending_in_person_enrollment,
      fraud_check_failed: fraud_check_failed,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account verification visited
  # @identity.idp.previous_event_name IdV: GPO verification visited
  # Visited page used to enter address verification code received via US mail.
  # @param [String,nil] source The source for the visit (i.e., "gpo_reminder_email").
  def idv_verify_by_mail_enter_code_visited(
    source: nil,
    **extra
  )
    track_event(
      'IdV: enter verify by mail code visited',
      source: source,
      **extra,
    )
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
  # The user clicked the troubleshooting option to start in-person proofing
  def idv_verify_in_person_troubleshooting_option_clicked(
    flow_path:,
    opted_in_to_in_person_proofing:,
    **extra
  )
    track_event(
      'IdV: verify in person troubleshooting option clicked',
      flow_path: flow_path,
      opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
      **extra,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] flow_path
  # @param [String] location
  # @param [Boolean] use_alternate_sdk
  def idv_warning_action_triggered(
    acuant_sdk_upgrade_a_b_testing_enabled:,
    acuant_version:,
    flow_path:,
    location:,
    use_alternate_sdk:,
    **_extra
  )
    track_event(
      'Frontend: IdV: warning action triggered',
      acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
      acuant_version: acuant_version,
      flow_path: flow_path,
      location: location,
      use_alternate_sdk: use_alternate_sdk,
    )
  end

  # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
  # @param [String] acuant_version
  # @param [String] error_message_displayed
  # @param [String] flow_path
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
    **_extra
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

  # @param [Integer] rendered_event_count how many events were rendered in the API response
  # @param [Boolean] authenticated whether the request was successfully authenticated
  # @param [Float] elapsed_time the amount of time the function took to run
  # @param [Boolean] success
  # An IRS Attempt API client has requested events
  def irs_attempts_api_events(
    rendered_event_count:,
    authenticated:,
    elapsed_time:,
    success:,
    **extra
  )
    track_event(
      'IRS Attempt API: Events submitted',
      rendered_event_count: rendered_event_count,
      authenticated: authenticated,
      elapsed_time: elapsed_time,
      success: success,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors
  # @param [Hash] error_details
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
  # @param [String] context
  # @param [Boolean] new_device
  # @param [String] multi_factor_auth_method
  # @param [DateTime] multi_factor_auth_method_created_at time auth method was created
  # @param [Integer] auth_app_configuration_id
  # @param [Integer] piv_cac_configuration_id
  # @param [Integer] key_id
  # @param [Integer] webauthn_configuration_id
  # @param [Integer] phone_configuration_id
  # @param [Boolean] confirmation_for_add_phone
  # @param [String] area_code
  # @param [String] country_code
  # @param [String] phone_fingerprint the hmac fingerprint of the phone number formatted as e164
  # @param [String] frontend_error Name of error that occurred in frontend during submission
  # Multi-Factor Authentication
  def multi_factor_auth(
    success:,
    errors: nil,
    context: nil,
    new_device: nil,
    multi_factor_auth_method: nil,
    multi_factor_auth_method_created_at: nil,
    auth_app_configuration_id: nil,
    piv_cac_configuration_id: nil,
    key_id: nil,
    webauthn_configuration_id: nil,
    confirmation_for_add_phone: nil,
    phone_configuration_id: nil,
    pii_like_keypaths: nil,
    area_code: nil,
    country_code: nil,
    phone_fingerprint: nil,
    frontend_error: nil,
    **extra
  )
    track_event(
      'Multi-Factor Authentication',
      success: success,
      errors: errors,
      context: context,
      new_device: new_device,
      multi_factor_auth_method: multi_factor_auth_method,
      multi_factor_auth_method_created_at: multi_factor_auth_method_created_at,
      auth_app_configuration_id: auth_app_configuration_id,
      piv_cac_configuration_id: piv_cac_configuration_id,
      key_id: key_id,
      webauthn_configuration_id: webauthn_configuration_id,
      confirmation_for_add_phone: confirmation_for_add_phone,
      phone_configuration_id: phone_configuration_id,
      pii_like_keypaths: pii_like_keypaths,
      area_code: area_code,
      country_code: country_code,
      phone_fingerprint: phone_fingerprint,
      frontend_error:,
      **extra,
    )
  end

  # Tracks when the the user has added the MFA method phone to their account
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  def multi_factor_auth_added_phone(enabled_mfa_methods_count:, **extra)
    track_event(
      'Multi-Factor Authentication: Added phone',
      {
        method_name: :phone,
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        **extra,
      }.compact,
    )
  end

  # @identity.idp.previous_event_name Multi-Factor Authentication: Added PIV_CAC
  # Tracks when the user has added the MFA method piv_cac to their account
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  # @param [Boolean] in_account_creation_flow whether user is going through creation flow
  def multi_factor_auth_added_piv_cac(enabled_mfa_methods_count:, in_account_creation_flow:,
                                      **extra)
    track_event(
      :multi_factor_auth_added_piv_cac,
      {
        method_name: :piv_cac,
        enabled_mfa_methods_count:,
        in_account_creation_flow:,
        **extra,
      }.compact,
    )
  end

  # Tracks when the user has added the MFA method TOTP to their account
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  # @param [Boolean] in_account_creation_flow whether user is going through creation flow
  def multi_factor_auth_added_totp(enabled_mfa_methods_count:, in_account_creation_flow:,
                                   **extra)
    track_event(
      'Multi-Factor Authentication: Added TOTP',
      {
        method_name: :totp,
        in_account_creation_flow:,
        enabled_mfa_methods_count:,
        **extra,
      }.compact,
    )
  end

  # A user has downloaded their backup codes
  def multi_factor_auth_backup_code_download
    track_event('Multi-Factor Authentication: download backup code')
  end

  # Tracks when the user visits the backup code confirmation setup page
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  # @param [Boolean] in_account_creation_flow whether user is going through creation flow
  def multi_factor_auth_enter_backup_code_confirmation_visit(
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: enter backup code confirmation visited',
      {
        enabled_mfa_methods_count:,
        in_account_creation_flow:,
        **extra,
      }.compact,
    )
  end

  # @param ["authentication","reauthentication","confirmation"] context user session context
  # User visited the page to enter a backup code as their MFA
  def multi_factor_auth_enter_backup_code_visit(context:, **extra)
    track_event(
      'Multi-Factor Authentication: enter backup code visited',
      context: context,
      **extra,
    )
  end

  # @param [String] context
  # @param [String] multi_factor_auth_method
  # @param [Boolean] confirmation_for_add_phone
  # @param [Integer] phone_configuration_id
  # Multi-Factor Authentication enter OTP visited
  def multi_factor_auth_enter_otp_visit(
    context:,
    multi_factor_auth_method:,
    confirmation_for_add_phone:,
    phone_configuration_id:,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: enter OTP visited',
      context: context,
      multi_factor_auth_method: multi_factor_auth_method,
      confirmation_for_add_phone: confirmation_for_add_phone,
      phone_configuration_id: phone_configuration_id,
      **extra,
    )
  end

  # @param ["authentication","reauthentication","confirmation"] context user session context
  # User visited the page to enter a personal key as their mfa (legacy flow)
  def multi_factor_auth_enter_personal_key_visit(context:, **extra)
    track_event(
      'Multi-Factor Authentication: enter personal key visited',
      context: context,
      **extra,
    )
  end

  # @identity.idp.previous_event_name 'Multi-Factor Authentication: enter PIV CAC visited'
  # @param ["authentication","reauthentication","confirmation"] context user session context
  # @param ["piv_cac"] multi_factor_auth_method
  # @param [Integer, nil] piv_cac_configuration_id PIV/CAC configuration database ID
  # User used a PIV/CAC as their mfa
  def multi_factor_auth_enter_piv_cac(
    context:,
    multi_factor_auth_method:,
    piv_cac_configuration_id:,
    **extra
  )
    track_event(
      :multi_factor_auth_enter_piv_cac,
      context: context,
      multi_factor_auth_method: multi_factor_auth_method,
      piv_cac_configuration_id: piv_cac_configuration_id,
      **extra,
    )
  end

  # @param ["authentication","reauthentication","confirmation"] context user session context
  # User visited the page to enter a TOTP as their mfa
  def multi_factor_auth_enter_totp_visit(context:, **extra)
    track_event('Multi-Factor Authentication: enter TOTP visited', context: context, **extra)
  end

  # @param ["authentication","reauthentication","confirmation"] context user session context
  # @param ["webauthn","webauthn_platform"] multi_factor_auth_method which webauthn method was used,
  # webauthn means a roaming authenticator like a yubikey, webauthn_platform means a platform
  # authenticator like face or touch ID
  # @param [Integer, nil] webauthn_configuration_id webauthn database ID
  # User visited the page to authenticate with webauthn (yubikey, face ID or touch ID)
  def multi_factor_auth_enter_webauthn_visit(
    context:,
    multi_factor_auth_method:,
    webauthn_configuration_id:,
    **extra
  )
    track_event(
      'Multi-Factor Authentication: enter webAuthn authentication visited',
      context: context,
      multi_factor_auth_method: multi_factor_auth_method,
      webauthn_configuration_id: webauthn_configuration_id,
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
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] selection
  def multi_factor_auth_option_list(success:, errors:, selection:, **extra)
    track_event(
      'Multi-Factor Authentication: option list',
      success: success,
      errors: errors,
      selection: selection,
      **extra,
    )
  end

  # User visited the list of multi-factor options to use
  def multi_factor_auth_option_list_visit
    track_event('Multi-Factor Authentication: option list visited')
  end

  # Multi factor auth phone setup
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] otp_delivery_preference
  # @param [String] area_code
  # @param [String] carrier
  # @param [String] country_code
  # @param [String] phone_type
  # @param [Hash] types
  def multi_factor_auth_phone_setup(success:,
                                    errors:,
                                    otp_delivery_preference:,
                                    area_code:,
                                    carrier:,
                                    country_code:,
                                    phone_type:,
                                    types:,
                                    **extra)
    track_event(
      'Multi-Factor Authentication: phone setup',
      success: success,
      errors: errors,
      otp_delivery_preference: otp_delivery_preference,
      area_code: area_code,
      carrier: carrier,
      country_code: country_code,
      phone_type: phone_type,
      types: types,
      **extra,
    )
  end

  # Tracks when a user sets up a multi factor auth method
  # @param [Boolean] success Whether authenticator setup was successful
  # @param [Hash] errors Authenticator setup error reasons, if unsuccessful
  # @param [String] multi_factor_auth_method
  # @param [Boolean] in_account_creation_flow whether user is going through account creation flow
  # @param [integer] enabled_mfa_methods_count
  def multi_factor_auth_setup(
    success:,
    multi_factor_auth_method:,
    enabled_mfa_methods_count:,
    in_account_creation_flow:,
    errors: nil,
    **extra
  )
    track_event(
      'Multi-Factor Authentication Setup',
      success: success,
      errors: errors,
      multi_factor_auth_method: multi_factor_auth_method,
      in_account_creation_flow: in_account_creation_flow,
      enabled_mfa_methods_count: enabled_mfa_methods_count,
      **extra,
    )
  end

  # @param [String] location Placement location
  # Logged when a browser with JavaScript disabled loads the detection stylesheet
  def no_js_detect_stylesheet_loaded(location:, **extra)
    track_event(:no_js_detect_stylesheet_loaded, location:, **extra)
  end

  # @param [Boolean] success
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors
  # @param [Hash] error_details
  # @param [String] method
  # OIDC Logout Requested
  def oidc_logout_requested(
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
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors
  # @param [Hash] error_details
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

  # @param [Boolean] success
  # @param [String] client_id
  # @param [Boolean] client_id_parameter_present
  # @param [Boolean] id_token_hint_parameter_present
  # @param [Boolean] sp_initiated
  # @param [Boolean] oidc
  # @param [Boolean] saml_request_valid
  # @param [Hash] errors
  # @param [Hash] error_details
  # @param [String] method
  # OIDC Logout Visited
  def oidc_logout_visited(
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
  # @param [String] client_id
  # @param [String] code_digest hash of returned "code" param
  def openid_connect_authorization_handoff(
    client_id:,
    code_digest:,
    **extra
  )
    track_event(
      'OpenID Connect: authorization request handoff',
      client_id: client_id,
      code_digest: code_digest,
      **extra,
    )
  end

  # Tracks when an openid connect bearer token authentication request is made
  # @param [Boolean] success
  # @param [Integer] ial
  # @param [String] client_id Service Provider issuer
  # @param [Hash] errors
  def openid_connect_bearer_token(success:, ial:, client_id:, errors:, **extra)
    track_event(
      'OpenID Connect: bearer token authentication',
      success: success,
      ial: ial,
      client_id: client_id,
      errors: errors,
      **extra,
    )
  end

  # Tracks when openid authorization request is made
  # @param [String] client_id
  # @param [String] scope
  # @param [Array] acr_values
  # @param [Array] vtr
  # @param [Boolean] unauthorized_scope
  # @param [Boolean] user_fully_authenticated
  def openid_connect_request_authorization(
    client_id:,
    scope:,
    acr_values:,
    vtr:,
    unauthorized_scope:,
    user_fully_authenticated:,
    **extra
  )
    track_event(
      'OpenID Connect: authorization request',
      client_id: client_id,
      scope: scope,
      acr_values: acr_values,
      vtr: vtr,
      unauthorized_scope: unauthorized_scope,
      user_fully_authenticated: user_fully_authenticated,
      **extra,
    )
  end

  # Tracks when an openid connect token request is made
  # @param [String] client_id
  # @param [String] user_id
  # @param [String] code_digest hash of "code" param
  # @param [Integer, nil] expires_in time to expiration of token
  # @param [Integer, nil] ial ial level of identity
  def openid_connect_token(client_id:, user_id:, code_digest:, expires_in:, ial:, **extra)
    track_event(
      'OpenID Connect: token',
      client_id: client_id,
      user_id: user_id,
      code_digest: code_digest,
      expires_in: expires_in,
      ial: ial,
      **extra,
    )
  end

  # Tracks when user makes an otp delivery selection
  # @param [String] otp_delivery_preference (sms or voice)
  # @param [Boolean] resend
  # @param [String] country_code
  # @param [String] area_code
  # @param ["authentication","reauthentication","confirmation"] context user session context
  # @param [Hash] pii_like_keypaths
  def otp_delivery_selection(
    otp_delivery_preference:,
    resend:,
    country_code:,
    area_code:,
    context:,
    pii_like_keypaths:,
    **extra
  )
    track_event(
      'OTP: Delivery Selection',
      otp_delivery_preference: otp_delivery_preference,
      resend: resend,
      country_code: country_code,
      area_code: area_code,
      context: context,
      pii_like_keypaths: pii_like_keypaths,
      **extra,
    )
  end

  # Tracks if otp phone validation failed
  # @identity.idp.previous_event_name Twilio Phone Validation Failed
  # @param [String] error
  # @param [String] context
  # @param [String] country
  def otp_phone_validation_failed(error:, context:, country:, **extra)
    track_event(
      'Vendor Phone Validation failed',
      error: error,
      context: context,
      country: country,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # The user updated their password
  def password_changed(success:, errors:, **extra)
    track_event('Password Changed', success: success, errors: errors, **extra)
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # The user added a password after verifying their email for account creation
  def password_creation(success:, errors:, **extra)
    track_event('Password Creation', success: success, errors: errors, **extra)
  end

  # The user got their password incorrect the max number of times, their session was terminated
  def password_max_attempts
    track_event('Password Max Attempts Reached')
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean, nil] confirmed if the account the reset is being requested for has a
  # confirmed email
  # @param [Boolean, nil] active_profile if the account the reset is being requested for has an
  # active proofed profile
  # @param [Hash] error_details Details for error that occurred in unsuccessful submission
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

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean] profile_deactivated if the active profile for the account was deactivated
  # (the user will need to use their personal key to reactivate their profile)
  # @param [Boolean] pending_profile_invalidated Whether a pending profile was invalidated as a
  # result of the password reset
  # @param [String] pending_profile_pending_reasons Comma-separated list of the pending states
  # associated with the associated profile.
  # @param [Hash] error_details Details for error that occurred in unsuccessful submission
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

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] user_id UUID of the user to receive password token
  # A password token has been sent for user
  def password_reset_token(success:, errors:, user_id:, **extra)
    track_event(
      'Password Reset: Token Submitted',
      success: success,
      errors: errors,
      user_id: user_id,
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

  # @param [Boolean] success
  # @param [Hash] errors
  # Alert user if a personal key was used to sign in
  def personal_key_alert_about_sign_in(success:, errors:, **extra)
    track_event(
      'Personal key: Alert user about sign in',
      success: success,
      errors: errors,
      **extra,
    )
  end

  # Account reactivated with personal key
  def personal_key_reactivation
    track_event('Personal key reactivation: Account reactivated with personal key')
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Hash] pii_like_keypaths
  # Personal key form submitted
  def personal_key_reactivation_submitted(success:, errors:, pii_like_keypaths:, **extra)
    track_event(
      'Personal key reactivation: Personal key form submitted',
      success: success,
      errors: errors,
      pii_like_keypaths: pii_like_keypaths,
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

  # @param [Boolean] success
  # @param [Hash] errors
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
    **extra
  )
    track_event(
      'Phone Number Change: Form submitted',
      success: success,
      errors: errors,
      delivery_preference: delivery_preference,
      phone_configuration_id: phone_configuration_id,
      make_default_number: make_default_number,
      **extra,
    )
  end

  # User has viewed the page to change their phone number
  def phone_change_viewed
    track_event('Phone Number Change: Visited')
  end

  # @param [Boolean] success
  # @param [Integer] phone_configuration_id
  # tracks a phone number deletion event
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
  # @param [Hash] error_details
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
  # @param [Boolean] success
  # @param [Hash] errors
  # tracks piv cac login event
  def piv_cac_login(success:, errors:, **extra)
    track_event(
      :piv_cac_login,
      success: success,
      errors: errors,
      **extra,
    )
  end

  def piv_cac_login_visited
    track_event(:piv_cac_login_visited)
  end

  # @identity.idp.previous_event_name User Registration: piv cac setup visited
  # @identity.idp.previous_event_name PIV CAC setup visited
  # Tracks when user's piv cac setup
  # @param [Boolean] in_account_creation_flow
  def piv_cac_setup_visited(in_account_creation_flow:, **extra)
    track_event(
      :piv_cac_setup_visited,
      in_account_creation_flow:,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] error_details
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

  # @param [true] success this event always succeeds
  # @param [Integer] emails number of email addresses the notification was sent to
  # @param [Array<String>] sms_message_ids AWS Pinpoint SMS message IDs for each phone number that
  # was notified
  # User has chosen to receive a new personal key, contains stats about notifications that
  # were sent to phone numbers and email addresses for the user
  def profile_personal_key_create_notifications(success:, emails:, sms_message_ids:, **extra)
    track_event(
      'Profile: Created new personal key notifications',
      success: success,
      emails: emails,
      sms_message_ids: sms_message_ids,
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

  # @identity.idp.previous_event_name Proofing Document Timeout
  # The job for document authentication did not record a result in the expected
  # place during the expected time frame
  def proofing_document_result_missing
    track_event('Proofing Document Result Missing')
  end

  # Tracks when a user triggered a rate limiter
  # @param [String] limiter_type
  # @identity.idp.previous_event_name Throttler Rate Limit Triggered
  def rate_limit_reached(limiter_type:, **extra)
    track_event(
      'Rate Limit Reached',
      limiter_type: limiter_type,
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
  # @param [String] validator_class Class name of validator
  # @param [String, nil] exception_class Class name of exception, if error occurred
  # @param [String, nil] phone_country_code Country code associated with reCAPTCHA phone result
  # @param [String] recaptcha_version
  def recaptcha_verify_result_received(
    recaptcha_result:,
    score_threshold:,
    evaluated_as_valid:,
    validator_class:,
    exception_class:,
    phone_country_code: nil,
    recaptcha_version: nil,
    **extra
  )
    track_event(
      'reCAPTCHA verify result received',
      {
        recaptcha_result:,
        score_threshold:,
        evaluated_as_valid:,
        validator_class:,
        exception_class:,
        phone_country_code:,
        recaptcha_version:,
        **extra,
      }.compact,
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
  # @param ['async'|'direct'] transport
  # @param [Integer] status
  # @param [String] error
  def risc_security_event_pushed(
    client_id:,
    event_type:,
    success:,
    transport:,
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
      transport:,
      **extra,
    )
  end

  # Tracks when rules of use is submitted with a success or failure
  # @param [Boolean] success
  # @param [Hash] errors
  def rules_of_use_submitted(success: nil, errors: nil, **extra)
    track_event(
      'Rules of Use Submitted',
      success: success,
      errors: errors,
      **extra,
    )
  end

  # Tracks when rules of use is visited
  def rules_of_use_visit
    track_event('Rules of Use Visited')
  end

  # Record SAML authentication payload Hash
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] nameid_format
  # @param [Array] authn_context
  # @param [String] authn_context_comparison
  # @param [String] service_provider
  def saml_auth(
    success:,
    errors:,
    nameid_format:,
    authn_context:,
    authn_context_comparison:,
    service_provider:,
    **extra
  )
    track_event(
      'SAML Auth',
      success: success,
      errors: errors,
      nameid_format: nameid_format,
      authn_context: authn_context,
      authn_context_comparison: authn_context_comparison,
      service_provider: service_provider,
      **extra,
    )
  end

  # @param [Integer] requested_ial
  # @param [String,nil] requested_aal_authn_context
  # @param [Boolean,nil] force_authn
  # @param [String] service_provider
  # An external request for SAML Authentication was received
  def saml_auth_request(
    requested_ial:,
    requested_aal_authn_context:,
    force_authn:,
    service_provider:,
    **extra
  )
    track_event(
      'SAML Auth Request',
      {
        requested_ial: requested_ial,
        requested_aal_authn_context: requested_aal_authn_context,
        force_authn: force_authn,
        service_provider: service_provider,
        **extra,
      }.compact,
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
  # @param [Boolean] success
  # @param [String] error_code
  # @param [Hash] errors
  # @param [String] jti
  # @param [String] user_id
  # @param [String] client_id
  def security_event_received(
    success:,
    error_code: nil,
    errors: nil,
    jti: nil,
    user_id: nil,
    client_id: nil,
    **extra
  )
    track_event(
      'RISC: Security event received',
      success: success,
      error_code: error_code,
      errors: errors,
      jti: jti,
      user_id: user_id,
      client_id: client_id,
      **extra,
    )
  end

  # tracks if the session is kept alive
  def session_kept_alive
    track_event('Session Kept Alive')
  end

  # tracks if the session timed out
  def session_timed_out
    track_event('Session Timed Out')
  end

  # tracks when a user's session is timed out
  def session_total_duration_timeout
    track_event('User Maximum Session Length Exceeded')
  end

  # @param [String] flash
  # tracks when a user visits the sign in page
  def sign_in_page_visit(flash:, **extra)
    track_event('Sign in page visited', flash:, **extra)
  end

  # @param [Boolean] success
  # @param [Boolean] new_user
  # @param [Boolean] has_other_auth_methods
  # @param [Integer] phone_configuration_id
  # tracks when a user opts into SMS
  def sms_opt_in_submitted(
    success:,
    new_user:,
    has_other_auth_methods:,
    phone_configuration_id:,
    **extra
  )
    track_event(
      'SMS Opt-In: Submitted',
      success: success,
      new_user: new_user,
      has_other_auth_methods: has_other_auth_methods,
      phone_configuration_id: phone_configuration_id,
      **extra,
    )
  end

  # @param [Boolean] new_user
  # @param [Boolean] has_other_auth_methods
  # @param [Integer] phone_configuration_id
  # tracks when a user visits the sms opt in page
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

  # Tracks when a user is redirected back to the service provider
  # @param [Integer] ial
  # @param [Integer] billed_ial
  # @param [String, nil] sign_in_flow
  def sp_redirect_initiated(ial:, billed_ial:, sign_in_flow:, **extra)
    track_event(
      'SP redirect initiated',
      ial:,
      billed_ial:,
      sign_in_flow:,
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

  # @param [String] area_code
  # @param [String] country_code
  # @param [String] phone_fingerprint the hmac fingerprint of the phone number formatted as e164
  # @param [String] context the context of the OTP, either "authentication" for confirmed phones
  # or "confirmation" for unconfirmed
  # @param ["sms","voice"] otp_delivery_preference the channel used to send the message
  # @param [Boolean] resend
  # @param [Hash] telephony_response
  # @param [:test, :pinpoint] adapter which adapter the OTP was delivered with
  # @param [Boolean] success
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
        **extra,
      },
    )
  end

  # Tracks when a user visits TOTP device setup
  # @param [Boolean] user_signed_up
  # @param [Boolean] totp_secret_present
  # @param [Integer] enabled_mfa_methods_count
  # @param [Boolean] in_account_creation_flow
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

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Integer] enabled_mfa_methods_count
  # @param [Integer] selected_mfa_count
  # @param ['voice', 'auth_app'] selection
  # Tracks when the the user has selected and submitted MFA auth methods on user registration
  def user_registration_2fa_setup(
    success:,
    errors: nil,
    selected_mfa_count: nil,
    enabled_mfa_methods_count: nil,
    selection: nil,
    **extra
  )
    track_event(
      'User Registration: 2FA Setup',
      {
        success: success,
        errors: errors,
        selected_mfa_count: selected_mfa_count,
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        selection: selection,
        **extra,
      }.compact,
    )
  end

  # Tracks when user visits MFA selection page
  # @param [Integer] enabled_mfa_methods_count Number of MFAs associated with user at time of visit
  def user_registration_2fa_setup_visit(enabled_mfa_methods_count:, **extra)
    track_event(
      'User Registration: 2FA Setup visited',
      enabled_mfa_methods_count:,
      **extra,
    )
  end

  # User registration has been handed off to agency page
  # @param [Boolean] ial2
  # @param [Integer] ialmax
  # @param [String] service_provider_name
  # @param [String] page_occurence
  # @param [String] needs_completion_screen_reason
  # @param [Array] sp_request_requested_attributes
  # @param [Array] sp_session_requested_attributes
  def user_registration_agency_handoff_page_visit(
      ial2:,
      service_provider_name:,
      page_occurence:,
      needs_completion_screen_reason:,
      sp_session_requested_attributes:,
      sp_request_requested_attributes: nil,
      ialmax: nil,
      **extra
    )
    track_event(
      'User registration: agency handoff visited',
      ial2: ial2,
      ialmax: ialmax,
      service_provider_name: service_provider_name,
      page_occurence: page_occurence,
      needs_completion_screen_reason: needs_completion_screen_reason,
      sp_request_requested_attributes: sp_request_requested_attributes,
      sp_session_requested_attributes: sp_session_requested_attributes,
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
  # @param [Boolean] ial2
  # @param [Boolean] ialmax
  # @param [String] service_provider_name
  # @param [String] page_occurence
  # @param [String] needs_completion_screen_reason
  # @param [Array] sp_request_requested_attributes
  # @param [Array] sp_session_requested_attributes
  # @param [String, nil] disposable_email_domain Disposable email domain used for registration
  def user_registration_complete(
    ial2:,
    service_provider_name:,
    page_occurence:,
    needs_completion_screen_reason:,
    sp_session_requested_attributes:,
    sp_request_requested_attributes: nil,
    ialmax: nil,
    disposable_email_domain: nil,
    **extra
  )
    track_event(
      'User registration: complete',
      ial2: ial2,
      ialmax: ialmax,
      service_provider_name: service_provider_name,
      page_occurence: page_occurence,
      needs_completion_screen_reason: needs_completion_screen_reason,
      sp_request_requested_attributes: sp_request_requested_attributes,
      sp_session_requested_attributes: sp_session_requested_attributes,
      disposable_email_domain: disposable_email_domain,
      **extra,
    )
  end

  # Tracks when user submits registration email
  # @param [Boolean] success
  # @param [Boolean] rate_limited
  # @param [Hash] errors
  # @param [Hash] error_details
  # @param [String] user_id
  # @param [Boolean] email_already_exists
  # @param [String] domain_name
  def user_registration_email(
    success:,
    rate_limited:,
    errors:,
    error_details: nil,
    user_id: nil,
    email_already_exists: nil,
    domain_name: nil,
    **extra
  )
    track_event(
      'User Registration: Email Submitted',
      {
        success:,
        rate_limited:,
        errors:,
        error_details:,
        user_id:,
        email_already_exists:,
        domain_name:,
        **extra,
      }.compact,
    )
  end

  # Tracks when user confirms registration email
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Hash] error_details
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
      success: success,
      errors: errors,
      error_details: error_details,
      user_id: user_id,
      **extra,
    )
  end

  # Tracks when user visits enter email page
  def user_registration_enter_email_visit
    track_event('User Registration: enter email visited')
  end

  # @param [Boolean] success
  # @param [Hash] mfa_method_counts
  # @param [Integer] enabled_mfa_methods_count
  # @param [Boolean] second_mfa_reminder_conversion Whether it is a result of second MFA reminder.
  # @param [Hash] pii_like_keypaths
  # Tracks when a user has completed MFA setup
  def user_registration_mfa_setup_complete(
    success:,
    mfa_method_counts:,
    enabled_mfa_methods_count:,
    pii_like_keypaths:,
    second_mfa_reminder_conversion: nil,
    **extra
  )
    track_event(
      'User Registration: MFA Setup Complete',
      {
        success: success,
        mfa_method_counts: mfa_method_counts,
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        pii_like_keypaths: pii_like_keypaths,
        second_mfa_reminder_conversion:,
        **extra,
      }.compact,
    )
  end

  # @param [Integer] enabled_mfa_methods_count
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
  def user_registration_user_fully_registered(
    mfa_method:,
    **extra
  )
    track_event(
      'User Registration: User Fully Registered',
      {
        mfa_method: mfa_method,
        **extra,
      }.compact,
    )
  end

  # Tracks when user reinstated
  # @param [Boolean] success
  # @param [String] error_message
  def user_reinstated(
    success:,
    error_message: nil,
    **extra
  )
    track_event(
      'User Suspension: Reinstated',
      {
        success: success,
        error_message: error_message,
        **extra,
      }.compact,
    )
  end

  # Tracks when user suspended
  # @param [Boolean] success
  # @param [String] error_message
  def user_suspended(
    success:,
    error_message: nil,
    **extra
  )
    track_event(
      'User Suspension: Suspended',
      {
        success: success,
        error_message: error_message,
        **extra,
      }.compact,
    )
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
  def usps_ippaas_enrollment_created(
    enrollment_code:,
    enrollment_id:,
    second_address_line_present:,
    service_provider:,
    **extra
  )
    track_event(
      'USPS IPPaaS enrollment created',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      second_address_line_present: second_address_line_present,
      service_provider: service_provider,
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
  # @param [Hash] error_details Details for error that occurred in unsuccessful submission
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

  # @param [Hash] platform_authenticator
  # @param [Boolean] success
  # @param [Hash, nil] errors
  # Tracks whether or not Webauthn setup was successful
  def webauthn_setup_submitted(platform_authenticator:, success:, errors: nil, **extra)
    track_event(
      :webauthn_setup_submitted,
      platform_authenticator: platform_authenticator,
      success: success,
      errors: errors,
      **extra,
    )
  end

  # @param [Hash] platform_authenticator
  # @param [Integer] enabled_mfa_methods_count
  # Tracks when WebAuthn setup is visited
  def webauthn_setup_visit(platform_authenticator:, enabled_mfa_methods_count:, **extra)
    track_event(
      'WebAuthn Setup Visited',
      platform_authenticator: platform_authenticator,
      enabled_mfa_methods_count: enabled_mfa_methods_count,
      **extra,
    )
  end

  # @param [Boolean] success Whether the submission was successful
  # @param [Integer] configuration_id Database ID for the configuration
  # @param [Boolean] platform_authenticator Whether the configuration was a platform authenticator
  # @param [Hash] error_details Details for error that occurred in unsuccessful submission
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
