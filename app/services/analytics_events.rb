# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module AnalyticsEvents
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
  # @param [Boolean] success
  # @param [String] user_id
  # @param [Integer, nil] account_age_in_days number of days since the account was confirmed
  # (rounded) or nil if the account was not confirmed
  # @param [Hash] mfa_method_counts
  # @param [Hash] errors
  # An account has been deleted through the account reset flow
  def account_reset_delete(
    success:,
    user_id:,
    account_age_in_days:,
    mfa_method_counts:,
    errors: nil,
    **extra
  )
    track_event(
      'Account Reset: delete',
      success: success,
      user_id: user_id,
      account_age_in_days: account_age_in_days,
      mfa_method_counts: mfa_method_counts,
      errors: errors,
      **extra,
    )
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

  # User visited the account deletion and reset page
  def account_reset_visit
    track_event('Account deletion and reset visited')
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

  # Tracks when the user creates a set of backup mfa codes.
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  def backup_code_created(enabled_mfa_methods_count:, **extra)
    track_event(
      'Backup Code Created',
      enabled_mfa_methods_count: enabled_mfa_methods_count,
      **extra,
    )
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

  # @param [String, nil] error error message
  # @param [String, nil] uuid document capture session uuid
  # @param [String, nil] result_id document capture session result id
  # When there is an error loading async results during the document authentication flow
  def doc_auth_async(error: nil, uuid: nil, result_id: nil, **extra)
    track_event('Doc Auth Async', error: error, uuid: uuid, result_id: result_id, **extra)
  end

  # @param [String] message the warining
  # Logged when there is a non-user-facing error in the doc auth process, such as an unrecognized
  # field from a vendor
  def doc_auth_warning(message: nil, **extra)
    track_event('Doc Auth Warning', message: message, **extra)
  end

  # @param [Boolean] success
  # @param [String] user_id
  # @param [Boolean] user_locked_out if the user is currently locked out of their second factor
  # @param [String] stored_location the URL to return to after signing in
  # @param [Boolean] sp_request_url_present if was an SP request URL in the session
  # @param [Boolean] remember_device if the remember device cookie was present
  # Tracks authentication attempts at the email/password screen
  def email_and_password_auth(
    success:,
    user_id:,
    user_locked_out:,
    stored_location:,
    sp_request_url_present:,
    remember_device:,
    **extra
  )
    track_event(
      'Email and Password Authentication',
      success: success,
      user_id: user_id,
      user_locked_out: user_locked_out,
      stored_location: stored_location,
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
  # Tracks request for adding new emails to an account
  def add_email_request(success:, errors:, **extra)
    track_event(
      'Add Email Requested',
      success: success,
      errors: errors,
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

  # Tracks if Email Language is visited
  def email_language_visited
    track_event('Email Language: Visited')
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

  # The user visited the "come back later" page shown during the GPO mailing flow
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  def idv_come_back_later_visit(proofing_components: nil, **extra)
    track_event(
      'IdV: come back later visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user clicked the troubleshooting option to start in-person proofing
  def idv_verify_in_person_troubleshooting_option_clicked(flow_path:, **extra)
    track_event(
      'IdV: verify in person troubleshooting option clicked',
      flow_path: flow_path,
      **extra,
    )
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user visited the in person proofing location step
  def idv_in_person_location_visited(flow_path:, **extra)
    track_event('IdV: in person proofing location visited', flow_path: flow_path, **extra)
  end

  # @param [String] selected_location Selected in-person location
  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user submitted the in person proofing location step
  def idv_in_person_location_submitted(selected_location:, flow_path:, **extra)
    track_event(
      'IdV: in person proofing location submitted',
      selected_location: selected_location,
      flow_path: flow_path,
      **extra,
    )
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user visited the in person proofing prepare step
  def idv_in_person_prepare_visited(flow_path:, **extra)
    track_event('IdV: in person proofing prepare visited', flow_path: flow_path, **extra)
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user submitted the in person proofing prepare step
  def idv_in_person_prepare_submitted(flow_path:, **extra)
    track_event('IdV: in person proofing prepare submitted', flow_path: flow_path, **extra)
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user visited the in person proofing switch_back step
  def idv_in_person_switch_back_visited(flow_path:, **extra)
    track_event('IdV: in person proofing switch_back visited', flow_path: flow_path, **extra)
  end

  # @param [String] flow_path Document capture path ("hybrid" or "standard")
  # The user submitted the in person proofing switch_back step
  def idv_in_person_switch_back_submitted(flow_path:, **extra)
    track_event('IdV: in person proofing switch_back submitted', flow_path: flow_path, **extra)
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user visited the "ready to verify" page for the in person proofing flow
  def idv_in_person_ready_to_verify_visit(proofing_components: nil, **extra)
    track_event(
      'IdV: in person ready to verify visited',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [String] step_name which step the user was on
  # @param [Integer] remaining_attempts how many attempts the user has left before we throttle them
  # The user visited an error page due to an encountering an exception talking to a proofing vendor
  def idv_doc_auth_exception_visited(step_name:, remaining_attempts:, **extra)
    track_event(
      'IdV: doc auth exception visited',
      step_name: step_name,
      remaining_attempts: remaining_attempts,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Integer] attempts
  # @param [Integer] remaining_attempts
  # @param [String] user_id
  # @param [String] flow_path
  # The document capture image uploaded was locally validated during the IDV process
  def idv_doc_auth_submitted_image_upload_form(
    success:,
    errors:,
    remaining_attempts:,
    flow_path:,
    attempts: nil,
    user_id: nil,
    **extra
  )
    track_event(
      'IdV: doc auth image upload form submitted',
      success: success,
      errors: errors,
      attempts: attempts,
      remaining_attempts: remaining_attempts,
      user_id: user_id,
      flow_path: flow_path,
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
  # @param [Integer] attempts
  # @param [Integer] remaining_attempts
  # @param [Hash] client_image_metrics
  # @param [String] flow_path
  # The document capture image was uploaded to vendor during the IDV process
  def idv_doc_auth_submitted_image_upload_vendor(
    success:,
    errors:,
    exception:,
    state:,
    state_id_type:,
    async:, attempts:,
    remaining_attempts:,
    client_image_metrics:,
    flow_path:,
    billed: nil,
    doc_auth_result: nil,
    **extra
  )
    track_event(
      'IdV: doc auth image upload vendor submitted',
      success: success,
      errors: errors,
      exception: exception,
      billed: billed,
      doc_auth_result: doc_auth_result,
      state: state,
      state_id_type: state_id_type,
      async: async,
      attempts: attempts,
      remaining_attempts: remaining_attempts,
      client_image_metrics: client_image_metrics,
      flow_path: flow_path,
      **extra,
    )
  end

  def idv_doc_auth_randomizer_defaulted
    track_event(
      'IdV: doc_auth random vendor error',
      error: 'document_capture_session_uuid_key missing',
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [String] user_id
  # @param [Integer] remaining_attempts
  # @param [Hash] pii_like_keypaths
  # @param [String] flow_path
  # The PII that came back from the document capture vendor was validated
  def idv_doc_auth_submitted_pii_validation(
    success:,
    errors:,
    remaining_attempts:,
    pii_like_keypaths:,
    flow_path:,
    user_id: nil,
    **extra
  )
    track_event(
      'IdV: doc auth image upload vendor pii validation',
      success: success,
      errors: errors,
      user_id: user_id,
      remaining_attempts: remaining_attempts,
      pii_like_keypaths: pii_like_keypaths,
      flow_path: flow_path,
      **extra,
    )
  end

  # @param [String] step_name
  # @param [Integer] remaining_attempts
  # The user was sent to a warning page during the IDV flow
  def idv_doc_auth_warning_visited(
    step_name:,
    remaining_attempts:,
    **extra
  )
    track_event(
      'IdV: doc auth warning visited',
      step_name: step_name,
      remaining_attempts: remaining_attempts,
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

  # @param [DateTime] enqueued_at
  # @param [Boolean] resend
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # GPO letter was enqueued and the time at which it was enqueued
  def idv_gpo_address_letter_enqueued(enqueued_at:, resend:, proofing_components: nil, **extra)
    track_event(
      'IdV: USPS address letter enqueued',
      enqueued_at: enqueued_at,
      resend: resend,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] resend
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # GPO letter was requested
  def idv_gpo_address_letter_requested(resend:, proofing_components: nil, **extra)
    track_event(
      'IdV: USPS address letter requested',
      resend: resend,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Boolean] letter_already_sent
  # GPO address visited
  def idv_gpo_address_visited(
    letter_already_sent:,
    **extra
  )
    track_event(
      'IdV: USPS address visited',
      letter_already_sent: letter_already_sent,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account verification submitted
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Hash] pii_like_keypaths
  # GPO verification submitted
  def idv_gpo_verification_submitted(
    success:,
    errors:,
    pii_like_keypaths:,
    **extra
  )
    track_event(
      'IdV: GPO verification submitted',
      success: success,
      errors: errors,
      pii_like_keypaths: pii_like_keypaths,
      **extra,
    )
  end

  # @identity.idp.previous_event_name Account verification visited
  # GPO verification visited
  def idv_gpo_verification_visited
    track_event('IdV: GPO verification visited')
  end

  # User visits IdV
  def idv_intro_visit
    track_event('IdV: intro visited')
  end

  # @param [Boolean] success
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # Tracks the last step of IDV, indicates the user successfully prooved
  def idv_final(
    success:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: final resolution',
      success: success,
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

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User submitted IDV personal key page
  def idv_personal_key_submitted(proofing_components: nil, **extra)
    track_event(
      'IdV: personal key submitted',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # A user has downloaded their backup codes
  def multi_factor_auth_backup_code_download
    track_event('Multi-Factor Authentication: download backup code')
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

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The user submitted their phone on the phone confirmation page
  def idv_phone_confirmation_form_submitted(
    success:,
    errors:,
    proofing_components: nil,
    **extra
  )
    track_event(
      'IdV: phone confirmation form',
      success: success,
      errors: errors,
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
  # @param ["sms","voice"] otp_delivery_preference which chaennel the OTP was delivered by
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
  # @param ["sms","voice"] otp_delivery_preference which chaennel the OTP was delivered by
  # @param [String] country_code country code of phone number
  # @param [String] area_code area code of phone number
  # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
  # @param [String] phone_fingerprint the hmac fingerprint of the phone number formatted as e164
  # @param [Hash] telephony_response response from Telephony gem
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
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

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean] code_expired if the confirmation code expired
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

  # @param ['warning','jobfail','failure'] type
  # @param [Time] throttle_expires_at when the throttle expires
  # @param [Integer] remaining_attempts number of attempts remaining
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # When a user gets an error during the phone finder flow of IDV
  def idv_phone_error_visited(
    type:,
    proofing_components: nil,
    throttle_expires_at: nil,
    remaining_attempts: nil,
    **extra
  )
    track_event(
      'IdV: phone error visited',
      {
        type: type,
        proofing_components: proofing_components,
        throttle_expires_at: throttle_expires_at,
        remaining_attempts: remaining_attempts,
        **extra,
      }.compact,
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
  # User visited idv phone of record
  def idv_phone_of_record_visited(proofing_components: nil, **extra)
    track_event(
      'IdV: phone of record visited',
      proofing_components: proofing_components,
      **extra,
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

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # The system encountered an error and the proofing results are missing
  def idv_proofing_resolution_result_missing(proofing_components: nil, **extra)
    track_event(
      'Proofing Resolution Result Missing',
      proofing_components: proofing_components,
      **extra,
    )
  end

  # User submitted IDV password confirm page
  # @param [Boolean] success
  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  def idv_review_complete(success:, proofing_components: nil, **extra)
    track_event(
      'IdV: review complete',
      success: success,
      proofing_components: proofing_components,
      **extra,
    )
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # User visited IDV password confirm page
  def idv_review_info_visited(proofing_components: nil, **extra)
    track_event(
      'IdV: review info visited',
      proofing_components: proofing_components,
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

  # @param [Integer] rendered_event_count how many events were rendered in the API response
  # @param [Boolean] success
  # An IRS Attempt API client has requested events
  def irs_attempts_api_events(
    rendered_event_count:,
    success:,
    **extra
  )
    track_event(
      'IRS Attempt API: Events submitted',
      rendered_event_count: rendered_event_count,
      success: success,
      **extra,
    )
  end

  # @param [String] event_type
  # @param [Integer] unencrypted_payload_num_bytes size of payload as JSON data
  # @param [Boolean] recorded if the full event was recorded or not
  def irs_attempts_api_event_metadata(
    event_type:,
    unencrypted_payload_num_bytes:,
    recorded:,
    **extra
  )
    track_event(
      'IRS Attempt API: Event metadata',
      event_type: event_type,
      unencrypted_payload_num_bytes: unencrypted_payload_num_bytes,
      recorded: recorded,
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
  # @param [Hash] errors
  # @param [String] context
  # @param [String] multi_factor_auth_method
  # @param [Integer] auth_app_configuration_id
  # @param [Integer] piv_cac_configuration_id
  # @param [Integer] key_id
  # @param [Integer] webauthn_configuration_id
  # @param [Integer] phone_configuration_id
  # @param [Boolean] confirmation_for_add_phone
  # @param [String] area_code
  # @param [String] country_code
  # @param [String] phone_fingerprint the hmac fingerprint of the phone number formatted as e164
  # Multi-Factor Authentication
  def multi_factor_auth(
    success:,
    errors: nil,
    context: nil,
    multi_factor_auth_method: nil,
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
    **extra
  )
    track_event(
      'Multi-Factor Authentication',
      success: success,
      errors: errors,
      context: context,
      multi_factor_auth_method: multi_factor_auth_method,
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

  # Tracks when the user has added the MFA method piv_cac to their account
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  def multi_factor_auth_added_piv_cac(enabled_mfa_methods_count:, **extra)
    track_event(
      'Multi-Factor Authentication: Added PIV_CAC',
      {
        method_name: :piv_cac,
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        **extra,
      }.compact,
    )
  end

  # Tracks when the user has added the MFA method TOTP to their account
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  def multi_factor_auth_added_totp(enabled_mfa_methods_count:, **extra)
    track_event(
      'Multi-Factor Authentication: Added TOTP',
      {
        method_name: :totp,
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        **extra,
      }.compact,
    )
  end

  # Tracks when the user has added the MFA method webauthn to their account
  # @param [Boolean] platform_authenticator indicates if webauthn_platform was used
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  def multi_factor_auth_added_webauthn(
    platform_authenticator:,
    enabled_mfa_methods_count:, **extra
  )
    track_event(
      'Multi-Factor Authentication: Added webauthn',
      {
        method_name: :webauthn,
        platform_authenticator: platform_authenticator,
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        **extra,
      }.compact,
    )
  end

  # Tracks when the user visits the backup code confirmation setup page
  # @param [Integer] enabled_mfa_methods_count number of registered mfa methods for the user
  def multi_factor_auth_enter_backup_code_confirmation_visit(
    enabled_mfa_methods_count:, **extra
  )
    track_event(
      'Multi-Factor Authentication: enter backup code confirmation visited',
      {
        enabled_mfa_methods_count: enabled_mfa_methods_count,
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

  # @param ["authentication","reauthentication","confirmation"] context user session context
  # User visited the page to enter a personal key as their mfa (legacy flow)
  def multi_factor_auth_enter_personal_key_visit(context:, **extra)
    track_event(
      'Multi-Factor Authentication: enter personal key visited',
      context: context,
      **extra,
    )
  end

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
      'Multi-Factor Authentication: enter PIV CAC visited',
      context: context,
      multi_factor_auth_method: multi_factor_auth_method,
      piv_cac_configuration_id: piv_cac_configuration_id,
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

  # Max multi factor max otp sends reached
  def multi_factor_auth_max_sends
    track_event('Multi-Factor Authentication: max otp sends reached')
  end

  # Tracks when a user sets up a multi factor auth method
  # @param [String] multi_factor_auth_method
  # @param [Boolean] in_multi_mfa_selection_flow
  # @param [integer] enabled_mfa_methods_count
  def multi_factor_auth_setup(multi_factor_auth_method:,
                              enabled_mfa_methods_count:, in_multi_mfa_selection_flow:,
                              **extra)
    track_event(
      'Multi-Factor Authentication Setup',
      multi_factor_auth_method: multi_factor_auth_method,
      in_multi_mfa_selection_flow: in_multi_mfa_selection_flow,
      enabled_mfa_methods_count: enabled_mfa_methods_count,
      **extra,
    )
  end

  # Track when users get directed to the prompt requiring multiple MFAs for Phone MFA
  def non_restricted_mfa_required_prompt_visited
    track_event('Non-Restricted MFA Required Prompt visited')
  end

  def non_restricted_mfa_required_prompt_skipped
    track_event('Non-Restricted MFA Required Prompt skipped')
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
  # @param [Boolean] unauthorized_scope
  # @param [Boolean] user_fully_authenticated
  # @param [String] code_digest hash of returned "code" param
  def openid_connect_request_authorization(
    client_id:,
    scope:,
    acr_values:,
    unauthorized_scope:,
    user_fully_authenticated:,
    code_digest:,
    **extra
  )
    track_event(
      'OpenID Connect: authorization request',
      client_id: client_id,
      scope: scope,
      acr_values: acr_values,
      unauthorized_scope: unauthorized_scope,
      user_fully_authenticated: user_fully_authenticated,
      code_digest: code_digest,
      **extra,
    )
  end

  # Tracks when an openid connect token request is made
  # @param [String] client_id
  # @param [String] user_id
  # @param [String] code_digest hash of "code" param
  def openid_connect_token(client_id:, user_id:, code_digest:, **extra)
    track_event(
      'OpenID Connect: token',
      client_id: client_id,
      user_id: user_id,
      code_digest: code_digest,
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

  # User has been marked as authenticated
  # @param [String] authentication_type
  def user_marked_authed(authentication_type:, **extra)
    track_event(
      'User marked authenticated',
      authentication_type: authentication_type,
      **extra,
    )
  end

  # User registration has been hadnded off to agency page
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
  # The user entered an email address to request a password reset
  def password_reset_email(success:, errors:, confirmed:, active_profile:, **extra)
    track_event(
      'Password Reset: Email Submitted',
      success: success,
      errors: errors,
      confirmed: confirmed,
      active_profile: active_profile,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean] profile_deactivated if the active profile for the account was deactivated
  # (the user will need to use their personal key to reactivate their profile)
  # The user changed the password for their account via the paswword reset flow
  def password_reset_password(success:, errors:, profile_deactivated:, **extra)
    track_event(
      'Password Reset: Password Submitted',
      success: success,
      errors: errors,
      profile_deactivated: profile_deactivated,
      **extra,
    )
  end

  # User has visited the page that lets them confirm if they want a new personal key
  def profile_personal_key_visit
    track_event('Profile: Visited new personal key')
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

  # Account reactivated with personal key as MFA
  def personal_key_reactivation_sign_in
    track_event(
      'Personal key reactivation: Account reactivated with personal key as MFA',
    )
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

  # @param [Boolean] success
  # @param [Hash] errors
  # tracks piv cac login event
  def piv_cac_login(success:, errors:, **extra)
    track_event(
      'PIV/CAC Login',
      success: success,
      errors: errors,
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

  # Rate limit triggered
  # @param [String] type
  def rate_limit_triggered(type:, **extra)
    track_event('Rate Limit Triggered', type: type, **extra)
  end

  # User authenticated by a remembered device
  def remembered_device_used_for_authentication
    track_event('Remembered device used for authentication')
  end

  # User initiated remote logout
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

  # Tracks when rules of use is visited
  def rules_of_use_visit
    track_event('Rules of Use Visited')
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

  # Tracks when a user is bounced back from the service provider due to an integration issue.
  def sp_handoff_bounced_detected
    track_event('SP handoff bounced detected')
  end

  # Tracks when a user visits the bounced page.
  def sp_handoff_bounced_visit
    track_event('SP handoff bounced visited')
  end

  # Tracks when a user vists the "This agency no longer uses Login.gov" page.
  def sp_inactive_visit
    track_event('SP inactive visited')
  end

  # Tracks when a user is redirected back to the service provider
  # @param [Integer] ial
  # @param [Integer] billed_ial
  def sp_redirect_initiated(ial:, billed_ial:, **extra)
    track_event(
      'SP redirect initiated',
      ial: ial,
      billed_ial: billed_ial,
      **extra,
    )
  end

  # Tracks when a user triggered a rate limit throttle
  # @param [String] throttle_type
  def throttler_rate_limit_triggered(throttle_type:, **extra)
    track_event(
      'Throttler Rate Limit Triggered',
      throttle_type: throttle_type,
      **extra,
    )
  end

  # Tracks when a user visits TOTP device setup
  # @param [Boolean] user_signed_up
  # @param [Boolean] totp_secret_present
  # @param [Integer] enabled_mfa_methods_count
  def totp_setup_visit(
    user_signed_up:,
    totp_secret_present:,
    enabled_mfa_methods_count:,
    **extra
  )
    track_event(
      'TOTP Setup Visited',
      user_signed_up: user_signed_up,
      totp_secret_present: totp_secret_present,
      enabled_mfa_methods_count: enabled_mfa_methods_count,
      **extra,
    )
  end

  # Tracks when a user disabled a TOTP device
  def totp_user_disabled
    track_event('TOTP: User Disabled')
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
  # @param [String] service_provider
  # An external request for SAML Authentication was received
  def saml_auth_request(
    requested_ial:,
    service_provider:,
    **extra
  )
    track_event(
      'SAML Auth Request',
      {
        requested_ial: requested_ial,
        service_provider: service_provider,
        **extra,
      }.compact,
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
  # @param [String] stored_location
  # tracks when a user visits the sign in page
  def sign_in_page_visit(flash:, stored_location:, **extra)
    track_event(
      'Sign in page visited',
      flash: flash,
      stored_location: stored_location,
      **extra,
    )
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

  # @param [String] area_code
  # @param [String] country_code
  # @param [String] phone_fingerprint the hmac fingerprint of the phone number formatted as e164
  # @param [String] context the context of the OTP, either "authentication" for confirmed phones
  # or "confirmation" for unconfirmed
  # @param ["sms","voice"] otp_delivery_preference the channel used to send the message
  # @param [Boolean] resend
  # @param [Hash] telephony_response
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
        success: success,
        **extra,
      },
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # Tracks when the the user has selected and submitted additional MFA methods on user registration
  def user_registration_2fa_additional_setup(success:, errors: nil, **extra)
    track_event(
      'User Registration: Additional 2FA Setup',
      {
        success: success,
        errors: errors,
        **extra,
      }.compact,
    )
  end

  # Tracks when user visits additional MFA selection page
  def user_registration_2fa_additional_setup_visit
    track_event('User Registration: Additional 2FA Setup visited')
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

  # @param [Boolean] success
  # @param [Hash] mfa_method_counts
  # @param [Integer] enabled_mfa_methods_count
  # @param [Hash] pii_like_keypaths
  # Tracks when a user has completed MFA setup
  def user_registration_mfa_setup_complete(
    success:,
    mfa_method_counts:,
    enabled_mfa_methods_count:,
    pii_like_keypaths:,
    **extra
  )
    track_event(
      'User Registration: MFA Setup Complete',
      {
        success: success,
        mfa_method_counts: mfa_method_counts,
        enabled_mfa_methods_count: enabled_mfa_methods_count,
        pii_like_keypaths: pii_like_keypaths,
        **extra,
      }.compact,
    )
  end

  # Tracks when user's piv cac is disabled
  def user_registration_piv_cac_disabled
    track_event('User Registration: piv cac disabled')
  end

  # Tracks when user's piv cac setup
  def user_registration_piv_cac_setup_visit(**extra)
    track_event(
      'User Registration: piv cac setup visited',
      **extra,
    )
  end

  # Tracks when user visits Suggest Another MFA Page
  def user_registration_suggest_another_mfa_notice_visited
    track_event('User Registration: Suggest Another MFA Notice visited')
  end

  # Tracks when user skips Suggest Another MFA Page
  def user_registration_suggest_another_mfa_notice_skipped
    track_event('User Registration: Suggest Another MFA Notice Skipped')
  end

  # Tracks when user visits MFA selection page
  def user_registration_2fa_setup_visit
    track_event('User Registration: 2FA Setup visited')
  end

  # @param [String] redirect_from
  # @param [Hash] vendor_status
  # Tracks when vendor has outage
  def vendor_outage(
    redirect_from:,
    vendor_status:,
    **extra
  )
    track_event(
      'Vendor Outage',
      redirect_from: redirect_from,
      vendor_status: vendor_status,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Integer] mfa_method_counts
  # Tracks when WebAuthn is deleted
  def webauthn_deleted(success:, mfa_method_counts:, pii_like_keypaths:, **extra)
    track_event(
      'WebAuthn Deleted',
      success: success,
      mfa_method_counts: mfa_method_counts,
      pii_like_keypaths: pii_like_keypaths,
      **extra,
    )
  end

  # @param [Hash] platform_authenticator
  # @param [Hash] errors
  # @param [Integer] enabled_mfa_methods_count
  # @param [Boolean] success
  # Tracks when WebAuthn setup is visited
  def webauthn_setup_visit(platform_authenticator:, errors:, enabled_mfa_methods_count:, success:,
                           **extra)
    track_event(
      'WebAuthn Setup Visited',
      platform_authenticator: platform_authenticator,
      errors: errors,
      enabled_mfa_methods_count: enabled_mfa_methods_count,
      success: success,
      **extra,
    )
  end

  # Tracks when user visits enter email page
  def user_registration_enter_email_visit
    track_event('User Registration: enter email visited')
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
  def user_registration_complete(
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
      'User registration: complete',
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

  # Tracks when user submits registration email
  # @param [Boolean] success
  # @param [Boolean] throttled
  # @param [Hash] errors
  # @param [Hash] error_details
  # @param [String] user_id
  # @param [String] domain_name
  def user_registration_email(
    success:,
    throttled:,
    errors:,
    error_details: nil,
    user_id: nil,
    domain_name: nil,
    **extra
  )
    track_event(
      'User Registration: Email Submitted',
      {
        success: success,
        throttled: throttled,
        errors: errors,
        error_details: error_details,
        user_id: user_id,
        domain_name: domain_name,
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

  # Tracks exceptions that are raised when running GetUspsProofingResultsJob
  # @param [String] reason why was the exception raised?
  # @param [String] enrollment_id
  # @param [String] exception_class
  # @param [String] exception_message
  # @param [String] enrollment_code
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
  def idv_in_person_usps_proofing_results_job_exception(
    reason:,
    enrollment_id:,
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
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Exception raised',
      reason: reason,
      enrollment_id: enrollment_id,
      exception_class: exception_class,
      exception_message: exception_message,
      enrollment_code: enrollment_code,
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
      **extra,
    )
  end

  # Tracks individual enrollments that are updated during GetUspsProofingResultsJob
  # @param [String] enrollment_code
  # @param [String] enrollment_id
  # @param [Boolean] fraud_suspected
  # @param [Boolean] passed did this enrollment pass or fail?
  # @param [String] reason why did this enrollment pass or fail?
  def idv_in_person_usps_proofing_results_job_enrollment_updated(
    enrollment_code:,
    enrollment_id:,
    fraud_suspected:,
    passed:,
    reason:,
    **extra
  )
    track_event(
      'GetUspsProofingResultsJob: Enrollment status updated',
      enrollment_code: enrollment_code,
      enrollment_id: enrollment_id,
      fraud_suspected: fraud_suspected,
      passed: passed,
      reason: reason,
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

  # Tracks users visiting the recovery options page
  def account_reset_recovery_options_visit
    track_event('Account Reset: Recovery Options Visited')
  end

  # Tracks users going back or cancelling acoount recovery
  def cancel_account_reset_recovery
    track_event('Account Reset: Cancel Account Recovery Options')
  end

  # @param [Idv::ProofingComponentsLogging] proofing_components User's current proofing components
  # Tracks when the user reaches the verify setup errors page after failing proofing
  def idv_setup_errors_visited(proofing_components: nil, **extra)
    track_event(
      'IdV: Verify setup errors visited',
      proofing_components: proofing_components,
      **extra,
    )
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

  # Tracks if a user clicks the "Show Password button"
  # @param [String] path URL path where the click occurred
  def show_password_button_clicked(path:, **extra)
    track_event('Show Password Button Clicked', path: path, **extra)
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

  # Logs after an email is sent
  # @param [String] action type of email being sent
  # @param [String, nil] ses_message_id AWS SES Message ID
  def email_sent(action:, ses_message_id:, **extra)
    track_event(
      'Email Sent',
      action: action,
      ses_message_id: ses_message_id,
      **extra,
    )
  end

  def idv_doc_auth_welcome_visited(**extra)
    track_event('IdV: doc auth welcome visited', **extra)
  end

  def idv_doc_auth_welcome_submitted(**extra)
    track_event('IdV: doc auth welcome submitted', **extra)
  end

  def idv_doc_auth_agreement_visited(**extra)
    track_event('IdV: doc auth agreement visited', **extra)
  end

  def idv_doc_auth_agreement_submitted(**extra)
    track_event('IdV: doc auth agreement submitted', **extra)
  end

  def idv_doc_auth_upload_visited(**extra)
    track_event('IdV: doc auth upload visited', **extra)
  end

  def idv_doc_auth_upload_submitted(**extra)
    track_event('IdV: doc auth upload submitted', **extra)
  end

  def idv_doc_auth_document_capture_visited(**extra)
    track_event('IdV: doc auth document_capture visited', **extra)
  end

  def idv_doc_auth_document_capture_submitted(**extra)
    track_event('IdV: doc auth document_capture submitted', **extra)
  end

  def idv_doc_auth_verify_document_status_submitted(**extra)
    track_event('IdV: doc auth verify_document_status submitted', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing ssn visited
  def idv_doc_auth_ssn_visited(**extra)
    track_event('IdV: doc auth ssn visited', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing ssn submitted
  def idv_doc_auth_ssn_submitted(**extra)
    track_event('IdV: doc auth ssn submitted', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing verify visited
  def idv_doc_auth_verify_visited(**extra)
    track_event('IdV: doc auth verify visited', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing verify submitted
  def idv_doc_auth_verify_submitted(**extra)
    track_event('IdV: doc auth verify submitted', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing verify_wait visited
  def idv_doc_auth_verify_wait_step_visited(**extra)
    track_event('IdV: doc auth verify_wait visited', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing optional verify_wait submitted
  def idv_doc_auth_optional_verify_wait_submitted(**extra)
    track_event('IdV: doc auth optional verify_wait submitted', **extra)
  end

  def idv_in_person_proofing_address_visited(**extra)
    track_event('IdV: in person proofing address visited', **extra)
  end

  def idv_in_person_proofing_address_submitted(**extra)
    track_event('IdV: in person proofing address submitted', **extra)
  end

  def idv_in_person_proofing_state_id_visited(**extra)
    track_event('IdV: in person proofing state_id visited', **extra)
  end

  def idv_in_person_proofing_state_id_submitted(**extra)
    track_event('IdV: in person proofing state_id submitted', **extra)
  end

  def idv_doc_auth_redo_document_capture_submitted(**extra)
    track_event('IdV: doc auth redo_document_capture submitted', **extra)
  end

  def idv_doc_auth_send_link_visited(**extra)
    track_event('IdV: doc auth send_link visited', **extra)
  end

  def idv_doc_auth_send_link_submitted(**extra)
    track_event('IdV: doc auth send_link submitted', **extra)
  end

  def idv_doc_auth_link_sent_visited(**extra)
    track_event('IdV: doc auth link_sent visited', **extra)
  end

  def idv_doc_auth_link_sent_submitted(**extra)
    track_event('IdV: doc auth send_link submitted', **extra)
  end

  def idv_doc_auth_cancel_send_link_submitted(**extra)
    track_event('IdV: doc auth cancel_send_link submitted', **extra)
  end

  def idv_doc_auth_cancel_link_sent_submitted(**extra)
    track_event('IdV: doc auth cancel_link_sent submitted', **extra)
  end

  def idv_doc_auth_capture_complete_visited(**extra)
    track_event('IdV: doc auth capture_complete visited', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing redo_address submitted
  def idv_doc_auth_redo_address_submitted(**extra)
    track_event('IdV: doc auth redo_address submitted', **extra)
  end

  def idv_doc_auth_redo_ssn_submitted(**extra)
    track_event('IdV: doc auth redo_ssn submitted', **extra)
  end

  def idv_in_person_proofing_redo_state_id_submitted(**extra)
    track_event('IdV: in person proofing redo_state_id submitted', **extra)
  end

  def idv_doc_auth_email_sent_visited(**extra)
    track_event('IdV: doc auth email_sent visited', **extra)
  end

  # @identity.idp.previous_event_name IdV: in person proofing cancel_update_ssn submitted
  def idv_doc_auth_cancel_update_ssn_submitted(**extra)
    track_event('IdV: doc auth cancel_update_ssn submitted', **extra)
  end

  def idv_in_person_proofing_cancel_update_state_id(**extra)
    track_event('IdV: in person proofing cancel_update_state_id submitted', **extra)
  end

  def idv_in_person_proofing_cancel_update_address(**extra)
    track_event('IdV: in person proofing cancel_update_address submitted', **extra)
  end
end
# rubocop:enable Metrics/ModuleLength
