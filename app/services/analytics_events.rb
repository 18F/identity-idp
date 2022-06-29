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
  # @param [Integer] account_age_in_days
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
  # The user clicked cancel during IDV (presented with an option to go back or confirm)
  def idv_cancellation_visited(step:, request_came_from:, **extra)
    track_event(
      'IdV: cancellation visited',
      step: step,
      request_came_from: request_came_from,
      **extra,
    )
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # The user confirmed their choice to cancel going through IDV
  def idv_cancellation_confirmed(step:, **extra)
    track_event('IdV: cancellation confirmed', step: step, **extra)
  end

  # @param [String] step the step that the user was on when they clicked cancel
  # The user chose to go back instead of cancel IDV
  def idv_cancellation_go_back(step:, **extra)
    track_event('IdV: cancellation go back', step: step, **extra)
  end

  # The user visited the "come back later" page shown during the GPO mailing flow
  def idv_come_back_later_visit
    track_event('IdV: come back later visited')
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

  # User visited forgot password page
  def idv_forgot_password
    track_event('IdV: forgot password visited')
  end

  # User confirmed forgot password
  def idv_forgot_password_confirmed
    track_event('IdV: forgot password confirmed')
  end

  # GPO address letter requested
  def idv_gpo_address_letter_requested
    track_event('IdV: USPS address letter requested')
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # GPO address submitted
  def idv_gpo_address_submitted(
    success:,
    errors:,
    **extra
  )
    track_event(
      'IdV: USPS address submitted',
      success: success,
      errors: errors,
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
  # Tracks the last step of IDV, indicates the user successfully prooved
  def idv_final(
    success:,
    **extra
  )
    track_event(
      'IdV: final resolution',
      success: success,
      **extra,
    )
  end

  # User visited IDV personal key page
  def idv_personal_key_visited
    track_event('IdV: personal key visited')
  end

  # User submitted IDV personal key page
  def idv_personal_key_submitted
    track_event('IdV: personal key submitted')
  end

  # A user has downloaded their backup codes
  def multi_factor_auth_backup_code_download
    track_event('Multi-Factor Authentication: download backup code')
  end

  # A user has downloaded their personal key. This event is no longer emitted.
  # @identity.idp.previous_event_name IdV: download personal key
  def idv_personal_key_downloaded
    track_event('IdV: personal key downloaded')
  end

  # @identity.idp.previous_event_name IdV: show personal key modal
  # User opened IDV personal key confirmation modal
  def idv_personal_key_confirm_visited
    track_event('IdV: personal key confirm visited')
  end

  # User submitted IDV personal key confirmation modal
  def idv_personal_key_confirm_submitted
    track_event('IdV: personal key confirm submitted')
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # The user submitted their phone on the phone confirmation page
  def idv_phone_confirmation_form_submitted(
    success:,
    errors:,
    **extra
  )
    track_event(
      'IdV: phone confirmation form',
      success: success,
      errors: errors,
      **extra,
    )
  end

  # The user was rate limited for submitting too many OTPs during the IDV phone step
  def idv_phone_confirmation_otp_rate_limit_attempts
    track_event('Idv: Phone OTP attempts rate limited')
  end

  # The user was locked out for hitting the phone OTP rate limit during IDV
  def idv_phone_confirmation_otp_rate_limit_locked_out
    track_event('Idv: Phone OTP rate limited user')
  end

  # The user was rate limited for requesting too many OTPs during the IDV phone step
  def idv_phone_confirmation_otp_rate_limit_sends
    track_event('Idv: Phone OTP sends rate limited')
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # @param ["sms","voice"] otp_delivery_preference which chaennel the OTP was delivered by
  # @param [String] country_code country code of phone number
  # @param [String] area_code area code of phone number
  # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
  # @param [Hash] telephony_response response from Telephony gem
  # The user resent an OTP during the IDV phone step
  def idv_phone_confirmation_otp_resent(
    success:,
    errors:,
    otp_delivery_preference:,
    country_code:,
    area_code:,
    rate_limit_exceeded:,
    telephony_response:,
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
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [Hash] errors
  # The vendor finished the process of confirming the users phone
  def idv_phone_confirmation_vendor_submitted(
    success:,
    errors:,
    **extra
  )
    track_event(
      'IdV: phone confirmation vendor',
      success: success,
      errors: errors,
      **extra,
    )
  end

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

  # When a user visits the page to confirm posession of a new phone number during the IDV process
  def idv_phone_confirmation_otp_visit
    track_event('IdV: phone confirmation otp visited')
  end

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

  # User visited idv phone of record
  def idv_phone_of_record_visited
    track_event('IdV: phone of record visited')
  end

  # User visited idv phone OTP delivery selection
  def idv_phone_otp_delivery_selection_visit
    track_event('IdV: Phone OTP delivery Selection Visited')
  end

  # @param [String] step the step the user was on when they clicked use a different phone number
  # User decided to use a different phone number in idv
  def idv_phone_use_different(step:, **extra)
    track_event(
      'IdV: use different phone number',
      step: step,
      **extra,
    )
  end

  # User submitted IDV password confirm page
  def idv_review_complete
    track_event('IdV: review complete')
  end

  # User visited IDV password confirm page
  def idv_review_info_visited
    track_event('IdV: review info visited')
  end

  # @param [String] step
  # @param [String] location
  # User started over idv
  def idv_start_over(
    step:,
    location:,
    **extra
  )
    track_event(
      'IdV: start over',
      step: step,
      location: location,
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

  # @param [Integer] acknowledged_event_count number of acknowledged events in the API call
  # @param [Integer] rendered_event_count how many events were rendered in the API response
  # @param [String] set_errors JSON encoded representation of SET errors from the client
  # An IRS Attempt API client has acknowledged receipt of security event tokens and polled for a
  # new set of events
  def irs_attempts_api_events(
    acknowledged_event_count:,
    rendered_event_count:,
    set_errors:,
    **extra
  )
    track_event(
      'IRS Attempt API: Events submitted',
      acknowledged_event_count: acknowledged_event_count,
      rendered_event_count: rendered_event_count,
      set_errors: set_errors,
      **extra,
    )
  end

  # @param [Boolean] success
  # @param [String] client_id
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
  def multi_factor_auth_setup(multi_factor_auth_method:, **extra)
    track_event(
      'Multi-Factor Authentication Setup',
      multi_factor_auth_method: multi_factor_auth_method,
      **extra,
    )
  end

  # Tracks when an openid connect bearer token authentication request is made
  # @param [Boolean] success
  # @param [Hash] errors
  def openid_connect_bearer_token(success:, errors:, **extra)
    track_event(
      'OpenID Connect: bearer token authentication',
      success: success,
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
  def openid_connect_request_authorization(
    client_id:,
    scope:,
    acr_values:,
    unauthorized_scope:,
    user_fully_authenticated:,
    **extra
  )
    track_event(
      'OpenID Connect: authorization request',
      client_id: client_id,
      scope: scope,
      acr_values: acr_values,
      unauthorized_scope: unauthorized_scope,
      user_fully_authenticated: user_fully_authenticated,
      **extra,
    )
  end

  # Tracks when an openid connect token request is made
  # @param [String] client_id
  # @param [String] user_id
  def openid_connect_token(client_id:, user_id:, **extra)
    track_event(
      'OpenID Connect: token',
      client_id: client_id,
      user_id: user_id,
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
  # @param [Hash] error_details
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
  # @param [Hash] errors
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
  # Tracks when the the user has selected and submitted MFA auth methods on user registration
  def user_registration_2fa_setup(success:, errors: nil, **extra)
    track_event(
      'User Registration: 2FA Setup',
      {
        success: success,
        errors: errors,
        **extra,
      }.compact,
    )
  end

  # Tracks when user visits MFA selection page
  def user_registration_2fa_setup_visit
    track_event('User Registration: 2FA Setup visited')
  end
end
# rubocop:enable Metrics/ModuleLength
