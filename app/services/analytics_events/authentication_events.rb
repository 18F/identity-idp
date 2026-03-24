# frozen_string_literal: true

module AnalyticsEvents
  module AuthenticationEvents

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
    # @param [String] client_id
    # @param [Boolean] client_id_parameter_present
    # @param [Boolean] id_token_hint_parameter_present
    # @param [Boolean] sp_initiated
    # @param [Boolean] oidc
    # @param [Boolean] saml_request_valid
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
    # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
    # @param [Boolean] available_webauthn_platform_config shows user has a webauth_platform config
    # @param [Integer] webauthn_auth_duration the duration to complete webauthn auth in seconds
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
      recaptcha_annotation: nil,
      available_webauthn_platform_config: nil,
      webauthn_auth_duration: nil,
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
        recaptcha_annotation:,
        available_webauthn_platform_config:,
        webauthn_auth_duration:,
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

    # A user has downloaded their backup codes
    def multi_factor_auth_backup_code_download
      track_event('Multi-Factor Authentication: download backup code')
    end

    # @param ["authentication", "reauthentication", "confirmation"] context User session context
    # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
    # User visited the page to enter a backup code as their MFA
    def multi_factor_auth_enter_backup_code_visit(context:, recaptcha_annotation: nil, **extra)
      track_event(
        'Multi-Factor Authentication: enter backup code visited',
        context: context,
        recaptcha_annotation:,
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
    # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
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
      recaptcha_annotation: nil,
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
        recaptcha_annotation:,
        **extra,
      )
    end

    # @param ["authentication", "reauthentication", "confirmation"] context User session context
    # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
    # User visited the page to enter a personal key as their mfa (legacy flow)
    def multi_factor_auth_enter_personal_key_visit(context:, recaptcha_annotation:, **extra)
      track_event(
        'Multi-Factor Authentication: enter personal key visited',
        context: context,
        recaptcha_annotation:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name 'Multi-Factor Authentication: enter PIV CAC visited'
    # @param ["authentication", "reauthentication", "confirmation"] context User session context
    # @param ["piv_cac"] multi_factor_auth_method
    # @param [Integer, nil] piv_cac_configuration_id PIV/CAC configuration database ID
    # @param [Boolean] new_device Whether the user is authenticating from a new device
    # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
    # User used a PIV/CAC as their mfa
    def multi_factor_auth_enter_piv_cac(
      context:,
      multi_factor_auth_method:,
      piv_cac_configuration_id:,
      new_device:,
      recaptcha_annotation: nil,
      **extra
    )
      track_event(
        :multi_factor_auth_enter_piv_cac,
        context: context,
        multi_factor_auth_method: multi_factor_auth_method,
        piv_cac_configuration_id: piv_cac_configuration_id,
        new_device:,
        recaptcha_annotation:,
        **extra,
      )
    end

    # @param ["authentication", "reauthentication", "confirmation"] context User session context
    # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
    # User visited the page to enter a TOTP as their mfa
    def multi_factor_auth_enter_totp_visit(context:, recaptcha_annotation: nil, **extra)
      track_event(
        'Multi-Factor Authentication: enter TOTP visited',
        context: context,
        recaptcha_annotation:,
        **extra,
      )
    end

    # @param ["authentication", "reauthentication", "confirmation"] context User session context
    # @param ["webauthn","webauthn_platform"] multi_factor_auth_method which webauthn method was used,
    #   webauthn means a roaming authenticator like a yubikey, webauthn_platform means a platform
    #   authenticator like face or touch ID
    # @param [Integer, nil] webauthn_configuration_id webauthn database ID
    # @param [String] multi_factor_auth_method_created_at When the authentication method was created
    # @param [Hash] recaptcha_annotation Details of reCAPTCHA annotation, if submitted
    # User visited the page to authenticate with webauthn (yubikey, face ID or touch ID)
    def multi_factor_auth_enter_webauthn_visit(
      context:,
      multi_factor_auth_method:,
      webauthn_configuration_id:,
      multi_factor_auth_method_created_at:,
      recaptcha_annotation: nil,
      **extra
    )
      track_event(
        'Multi-Factor Authentication: enter webAuthn authentication visited',
        context:,
        multi_factor_auth_method:,
        webauthn_configuration_id:,
        multi_factor_auth_method_created_at:,
        recaptcha_annotation:,
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
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] selection
    # @param [integer] enabled_mfa_methods_count Number of enabled MFA methods on the account
    # @param [Hash] mfa_method_counts Hash of MFA method with the number of that method on the account
    def multi_factor_auth_option_list(
      success:,
      selection:,
      enabled_mfa_methods_count:,
      mfa_method_counts:,
      error_details: nil,
      **extra
    )
      track_event(
        'Multi-Factor Authentication: option list',
        success:,
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
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
    # @param [String] area_code
    # @param [String] carrier Pinpoint detected phone carrier
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] phone_type Pinpoint phone classification type
    # @param [Array<String>] types Phonelib parsed phone types
    def multi_factor_auth_phone_setup(
        success:,
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
    # @param [String[], nil] transports WebAuthn transports associated with registration.
    # @param [Boolean, nil] transports_mismatch Whether the WebAuthn transports associated with
    #   registration contradict the authenticator attachment for user setup. For example, a user can
    #   set up a platform authenticator through the Security Key setup flow.
    # @param [:authentication, :account_creation, nil] webauthn_platform_recommended A/B test for
    # @param [Integer, nil] webauthn_setup_duration Duration of webauthn setup in seconds
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
      transports: nil,
      transports_mismatch: nil,
      webauthn_platform_recommended: nil,
      webauthn_setup_duration: nil,
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
        transports:,
        transports_mismatch:,
        webauthn_platform_recommended:,
        webauthn_setup_duration:,
        **extra,
      )
    end

    # Tracks when user makes an otp delivery selection
    # @param [Boolean] success Whether the form was submitted successfully.
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param ["authentication","reauthentication","confirmation"] context User session context
    # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
    # @param [Boolean] resend True if the user re-requested a code
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] area_code Area code of phone number
    def otp_delivery_selection(
      success:,
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

    # Tracks when passkey authentication is initiated
    def passkey_authentication_initiated
      track_event(:passkey_authentication_initiated)
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Boolean] active_profile_present Whether active profile existed at time of change
    # @param [Boolean] pending_profile_present Whether pending profile existed at time of change
    # @param [Boolean] required_password_change Whether password change was forced due to compromised
    #   password
    # The user updated their password
    def password_changed(
      success:,
      active_profile_present:,
      pending_profile_present:,
      required_password_change:,
      error_details: nil,
      **extra
    )
      track_event(
        'Password Changed',
        success:,
        error_details:,
        active_profile_present:,
        pending_profile_present:,
        required_password_change:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] user_id UUID of the user
    # @param [Boolean] request_id_present Whether request_id URL parameter is present
    # The user added a password after verifying their email for account creation
    def password_creation(
      success:,
      user_id:,
      request_id_present:,
      error_details: nil,
      **extra
    )
      track_event(
        'Password Creation',
        success:,
        error_details:,
        user_id:,
        request_id_present:,
        **extra,
      )
    end

    # @param [Boolean, nil] active_profile if the account the reset is being requested for has an
    #   active proofed profile
    #   The user signed in with a password found on the pwned list
    def password_found_on_pwned_list(
      active_profile:,
      **extra
    )
      track_event(
        :password_found_on_pwned_list,
        active_profile:,
        **extra,
      )
    end

    # The user got their password incorrect the max number of times, their session was terminated
    def password_max_attempts
      track_event('Password Max Attempts Reached')
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Boolean, nil] confirmed if the account the reset is being requested for has a
    #   confirmed email
    # @param [Boolean, nil] active_profile if the account the reset is being requested for has an
    #   active proofed profile
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # The user entered an email address to request a password reset
    def password_reset_email(
      success:,
      confirmed:,
      active_profile:,
      error_details: nil,
      **extra
    )
      track_event(
        'Password Reset: Email Submitted',
        success:,
        error_details:,
        confirmed:,
        active_profile:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
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
      profile_deactivated:,
      pending_profile_invalidated:,
      pending_profile_pending_reasons:,
      error_details: nil,
      **extra
    )
      track_event(
        'Password Reset: Password Submitted',
        success:,
        error_details:,
        profile_deactivated:,
        pending_profile_invalidated:,
        pending_profile_pending_reasons:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] user_id UUID of the user to receive password token
    # A password token has been sent for user
    def password_reset_token(success:, user_id:, error_details: nil, **extra)
      track_event(
        'Password Reset: Token Submitted',
        success:,
        error_details:,
        user_id:,
        **extra,
      )
    end

    # Password reset form has been visited.
    def password_reset_visit
      track_event('Password Reset: Email Form Visited')
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] delivery_preference
    # @param [Integer] phone_configuration_id
    # @param [Boolean] make_default_number
    # User has submitted a change in phone number
    def phone_change_submitted(
      success:,
      delivery_preference:,
      phone_configuration_id:,
      make_default_number:,
      error_details: nil,
      **extra
    )
      track_event(
        'Phone Number Change: Form submitted',
        success:,
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
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String, nil] key_id PIV/CAC key_id from PKI service
    # @param [Boolean] new_device Whether the user is authenticating from a new device
    # Tracks piv cac login event
    def piv_cac_login(success:, key_id:, new_device:, error_details: nil, **extra)
      track_event(
        :piv_cac_login,
        success:,
        key_id:,
        new_device:,
        error_details:,
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
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] jti
    # @param [String] user_id
    # @param [String] client_id
    # @param [String] event_type
    def security_event_received(
      success:,
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
        error_details:,
        event_type:,
        error_code:,
        jti:,
        user_id:,
        client_id:,
        **extra,
      )
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
      new_user:,
      has_other_auth_methods:,
      phone_configuration_id:,
      errors: nil,
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

    # @param [String] area_code Area code of phone number
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
    # @param [String, nil] ip_country 2-letter country code associated with request IP address
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
      context:, otp_delivery_preference:, resend:, telephony_response:, adapter:, success:,
      ip_country: nil,
      recaptcha_annotation: nil,
      **extra
    )
      track_event(
        'Telephony: OTP sent',
        {
          area_code: area_code,
          country_code: country_code,
          phone_fingerprint: phone_fingerprint,
          ip_country: ip_country,
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

    # @param [Boolean] platform_authenticator Whether authentication method was registered as platform
    #   authenticator
    # @param [Number] configuration_id Database ID of WebAuthn configuration
    # @param [Boolean] confirmed_mismatch Whether user chose to confirm and continue with interpreted
    #   platform attachment
    # @param [Boolean] success Whether the deletion was successful, if user chose to undo interpreted
    #   platform attachment
    # @param [Hash] error_details Details for errors that occurred in unsuccessful deletion
    # User submitted confirmation screen after setting up WebAuthn with transports mismatched with the
    # expected platform attachment
    def webauthn_setup_mismatch_submitted(
      configuration_id:,
      platform_authenticator:,
      confirmed_mismatch:,
      success: nil,
      error_details: nil,
      **extra
    )
      track_event(
        :webauthn_setup_mismatch_submitted,
        configuration_id:,
        platform_authenticator:,
        confirmed_mismatch:,
        success:,
        error_details:,
        **extra,
      )
    end

    # @param [Boolean] platform_authenticator Whether authentication method was registered as platform
    #   authenticator
    # @param [Number] configuration_id Database ID of WebAuthn configuration
    # User visited confirmation screen after setting up WebAuthn with transports mismatched with the
    # expected platform attachment
    def webauthn_setup_mismatch_visited(
      configuration_id:,
      platform_authenticator:,
      **extra
    )
      track_event(
        :webauthn_setup_mismatch_visited,
        configuration_id:,
        platform_authenticator:,
        **extra,
      )
    end

    # @param [Boolean] platform_authenticator Whether submission is for setting up a platform
    #   authenticator. This aligns to what the user experienced in setting up the authenticator.
    #   However, if `transports_mismatch` is true, the authentication method is created as the
    #   opposite of this value.
    # @param [Boolean] success Whether the submission was successful
    # @param [Hash, nil] errors Errors resulting from form validation, or nil if successful.
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
        platform_authenticator:,
        success:,
        errors:,
        in_account_creation_flow:,
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
end
