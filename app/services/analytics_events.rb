module AnalyticsEvents
  # @identity.idp.event_name Account Reset
  # @param [Boolean] success
  # @param ["cancel", "delete", "cancel token validation", "granted token validation",
  #  "notifications"] event
  # @param [String] message_id from AWS Pinpoint API
  # @param [String] request_id from AWS Pinpoint API
  # @param [Boolean] sms_phone
  # @param [Boolean] totp does the user have an authentication app as a 2FA option?
  # @param [Boolean] piv_cac does the user have PIV/CAC as a 2FA option?
  # @param [Integer] count number of notifications sent
  # @param [Hash] errors
  # @param [Hash] error_details
  # @param [String] user_id
  # @param [Integer] account_age_in_days
  # @param [Hash] mfa_method_counts
  # @param [Integer] email_addresses number of email addresses the user has
  # Tracks events related to a user requesting to delete their account during the sign in process
  # (because they have no other means to sign in).
  def account_reset(
    success: nil,
    event: nil,
    message_id: nil,
    piv_cac: nil,
    request_id: nil,
    sms_phone: nil,
    totp: nil,
    count: nil,
    errors: nil,
    user_id: nil,
    account_age_in_days: nil,
    mfa_method_counts: nil,
    pii_like_keypaths: nil,
    error_details: nil,
    email_addresses: nil,
    **extra
  )
    track_event(
      'Account Reset',
      {
        success: success,
        event: event,
        message_id: message_id,
        piv_cac: piv_cac,
        request_id: request_id,
        sms_phone: sms_phone,
        totp: totp,
        count: count,
        errors: errors,
        user_id: user_id,
        account_age_in_days: account_age_in_days,
        mfa_method_counts: mfa_method_counts,
        pii_like_keypaths: pii_like_keypaths,
        error_details: error_details,
        email_addresses: email_addresses,
        **extra,
      }.compact,
    )
  end

  # @identity.idp.event_name Account Delete submitted
  # @param [Boolean] success
  # When a user submits a form to delete their account
  def account_delete_submitted(success:, **extra)
    track_event('Account Delete submitted', success: success, **extra)
  end

  # @identity.idp.event_name Account Delete visited
  # When a user visits the page to delete their account
  def account_delete_visited
    track_event('Account Delete visited')
  end

  # @identity.idp.event_name Account Deletion Requested
  # @param [String] request_came_from the controller/action the request came from
  # When a user deletes their account
  def account_deletion(request_came_from:, **extra)
    track_event('Account Deletion Requested', request_came_from: request_came_from, **extra)
  end

  # @identity.idp.event_name Account deletion and reset visited
  # When a user views the account page
  def account_visit
    track_event('Account Page Visited')
  end

  # @identity.idp.event_name Add Email: Email Confirmation
  # @param [Boolean] success
  # @param [String] user_id account the email is linked to
  # A user has clicked the confirmation link in an email
  def add_email_confirmation(user_id:, success: nil, **extra)
    track_event('Add Email: Email Confirmation', user_id: user_id, success: success, **extra)
  end

  # @identity.idp.event_name Authentication Confirmation
  # When a user views the "you are already signed in with the following email" screen
  def authentication_confirmation
    track_event('Authentication Confirmation')
  end

  # @identity.idp.event_name Authentication Confirmation: Continue selected
  # When a user views the "you are already signed in with the following email" screen and
  # continues with their existing logged-in email
  def authentication_confirmation_continue
    track_event('Authentication Confirmation: Continue selected')
  end

  # @identity.idp.event_name Authentication Confirmation: Reset selected
  # When a user views the "you are already signed in with the following email" screen and
  # signs out of their current logged in email to choose a different email
  def authentication_confirmation_reset
    track_event('Authentication Confirmation: Reset selected')
  end

  # @identity.idp.event_name Banned User redirected
  # A user that has been banned from an SP has authenticated, they are redirected
  # to a page showing them that they have been banned
  def banned_user_redirect
    track_event('Banned User redirected')
  end

  # @identity.idp.event_name Banned User visited
  # A user that has been banned from an SP has authenticated, they have visited
  # a page showing them that they have been banned
  def banned_user_visited
    track_event('Banned User visited')
  end

  # @identity.idp.event_name Broken Personal Key: Regenerated
  # A user that had a broken personal key was routed to a page to regenerate their personal key,
  # so that they no longer have a broken one
  def broken_personal_key_regenerated
    track_event('Broken Personal Key: Regenerated')
  end

  # @identity.idp.event_name Doc Auth Async
  # @param [String, nil] error error message
  # @param [String, nil] uuid document capture session uuid
  # @param [String, nil] result_id document capture session result id
  # When there is an error loading async results during the document authentication flow
  def doc_auth_async(error: nil, uuid: nil, result_id: nil, **extra)
    track_event('Doc Auth Async', error: error, uuid: uuid, result_id: result_id, **extra)
  end

  # @identity.idp.event_name Doc Auth Warning
  # @param [String] message the warining
  # Logged when there is a non-user-facing error in the doc auth process, such as an unrecognized
  # field from a vendor
  def doc_auth_warning(message: nil, **extra)
    track_event('Doc Auth Warning', message: message, **extra)
  end

  # @identity.idp.event_name Email and Password Authentication
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

  # @deprecated
  # A user has downloaded their personal key. This event is no longer emitted.
  # @identity.idp.event_name IdV: personal key downloaded
  # @identity.idp.previous_event_name IdV: download personal key
  def idv_personal_key_downloaded
    track_event('IdV: personal key downloaded')
  end

  # @identity.idp.event_name IdV: phone confirmation otp submitted
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Boolean] code_expired if the confirmation code expired
  # @param [Boolean] code_matches
  # @param [Integer] second_factor_attempts_count number of attempts to confirm this phone
  # @param [Time, nil] second_factor_locked_at timestamp when the phone was
  # locked out at
  # When a user attempts to confirm posession of a new phone number during the IDV process
  def idv_phone_confirmation_otp_submitted(
    success:,
    errors:,
    code_expired:,
    code_matches:,
    second_factor_attempts_count:,
    second_factor_locked_at:,
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
      **extra,
    )
  end

  # @identity.idp.event_name IdV: phone confirmation otp visited
  # When a user visits the page to confirm posession of a new phone number during the IDV process
  def idv_phone_confirmation_otp_visit
    track_event('IdV: phone confirmation otp visited')
  end

  # @identity.idp.event_name IdV: phone error visited
  # @param ['warning','jobfail','failure'] type
  # @param [Time] throttle_expires_at when the throttle expires
  # @param [Integer] remaining_attempts number of attempts remaining
  # When a user gets an error during the phone finder flow of IDV
  def idv_phone_error_visited(type:, throttle_expires_at: nil, remaining_attempts: nil, **extra)
    track_event(
      'IdV: phone error visited',
      {
        type: type,
        throttle_expires_at: throttle_expires_at,
        remaining_attempts: remaining_attempts,
        **extra,
      }.compact,
    )
  end

  # @identity.idp.event_name IdV: Phone OTP Delivery Selection Submitted
  # @param ["sms", "voice"] otp_delivery_preference
  # @param [Boolean] success
  # @param [Hash] errors
  # @param [Hash] error_details
  def idv_phone_otp_delivery_selection_submitted(
    success:,
    otp_delivery_preference:,
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
        **extra,
      }.compact,
    )
  end

  # @identity.idp.event_name Profile: Visited new personal key
  # User has visited the page that lets them confirm if they want a new personal key
  def profile_personal_key_visit
    track_event('Profile: Visited new personal key')
  end

  # @identity.idp.event_name Profile: Created new personal key
  # @see #profile_personal_key_create_notifications
  # User has chosen to receive a new personal key
  def profile_personal_key_create
    track_event('Profile: Created new personal key')
  end

  # @identity.idp.event_name Profile: Created new personal key notifications
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

  # @identity.idp.event_name Proofing Address Result Missing
  # @identity.idp.previous_event_name Proofing Address Timeout
  # The job for address verification (PhoneFinder) did not record a result in the expected
  # place during the expected time frame
  def proofing_address_result_missing
    track_event('Proofing Address Result Missing')
  end

  # @identity.idp.event_name Proofing Document Result Missing
  # @identity.idp.previous_event_name Proofing Document Timeout
  # The job for document authentication did not record a result in the expected
  # place during the expected time frame
  def proofing_document_result_missing
    track_event('Proofing Document Result Missing')
  end

  # @identity.idp.event_name Return to SP: Failed to proof
  # Tracks when a service provide fails to proof.
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

  # @identity.idp.event_name Rules of Use Visited
  # Tracks when rules of use is visited
  def rules_of_use_visit
    track_event('Rules of Use Visited')
  end

  # @identity.idp.event_name Rules of Use Submitted
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

  # @identity.idp.event_name RISC: Security event received
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

  # @identity.idp.event_name SP Revoke Consent: Revoked
  # Tracks when service provider consent is revoked
  # @param [String] issuer issuer of the service provider consent to be revoked
  def sp_revoke_consent_revoked(issuer:, **extra)
    track_event(
      'SP Revoke Consent: Revoked',
      issuer: issuer,
      **extra,
    )
  end

  # @identity.idp.event_name SP Revoke Consent: Visited
  # Tracks when the page to revoke consent (unlink from) a service provider visited
  # @param [String] issuer which issuer
  def sp_revoke_consent_visited(issuer:, **extra)
    track_event(
      'SP Revoke Consent: Visited',
      issuer: issuer,
      **extra,
    )
  end

  # @identity.idp.event_name SAML Auth Request
  # @param [Boolean] identity_needs_verification indicates whether identity verification is needed
  # @param [Boolean] profile_needs_verification indicates if proofing is needed for a pending/reset
  # profile
  # @param [Integer] requested_ial
  # @param [String] service_provider
  # An external request for SAML Authentication was received
  def saml_auth_request(
    identity_needs_verification:,
    profile_needs_verification:,
    requested_ial:,
    service_provider:,
    **extra
  )
    track_event(
      'SAML Auth Request',
      {
        identity_needs_verification: identity_needs_verification,
        profile_needs_verification: profile_needs_verification,
        requested_ial: requested_ial,
        service_provider: service_provider,
        **extra,
      }.compact,
    )
  end
end
