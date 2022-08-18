module IrsAttemptsApi
  module TrackerEvents
    # @param [String] email The submitted email address
    # @param [Boolean] success True if the email and password matched
    # A user has submitted an email address and password for authentication
    def email_and_password_auth(email:, success:)
      track_event(
        :email_and_password_auth,
        email: email,
        success: success,
      )
    end

    # @param [Boolean] success True if the email and password matched
    # A user has initiated a logout event
    def logout_initiated(success:)
      track_event(
        :logout_initiated,
        success: success,
      )
    end

    # @param [Boolean] success True if selection was valid
    # @param [Array<String>] mfa_device_types List of MFA options users selected on account creation
    # A user has selected MFA options
    def mfa_enroll_options_selected(success:, mfa_device_types:)
      track_event(
        :mfa_enroll_options_selected,
        success: success,
        mfa_device_types: mfa_device_types,
      )
    end

    # Tracks when the user has attempted to enroll the Backup Codes MFA method to their account
    # @param [Boolean] success
    def mfa_enroll_backup_code(success:)
      track_event(
        :mfa_enroll_backup_code,
        success: success,
      )
    end

    # @param [String] phone_number - The user's phone_number used for multi-factor authentication
    # @param [Boolean] success - True if the OTP Verification was sent
    # Relevant only when the user is enrolling a phone as their MFA.
    # The user has been sent an OTP by login.gov over SMS during the MFA enrollment process.
    def mfa_enroll_phone_otp_sent(phone_number:, success:)
      track_event(
        :mfa_enroll_phone_otp_sent,
        phone_number: phone_number,
        success: success,
      )
    end

    # @param [Boolean] success - True if the sms otp submitted matched what was sent
    # The user, after having previously been sent an OTP code during phone enrollment
    # has been asked to submit that code.
    def mfa_enroll_phone_otp_submitted(success:)
      track_event(
        :mfa_enroll_phone_otp_submitted,
        success: success,
      )
    end

    # Tracks when the user has attempted to enroll the TOTP MFA method to their account
    # @param [Boolean] success
    def mfa_enroll_totp(success:)
      track_event(
        :mfa_enroll_totp,
        success: success,
      )
    end

    # Tracks when the user has attempted to enroll the WebAuthn-Platform MFA method to their account
    # @param [Boolean] success
    def mfa_enroll_webauthn_platform(success:)
      track_event(
        :mfa_enroll_webauthn_platform,
        success: success,
      )
    end

    # Tracks when the user has attempted to enroll the WebAuthn MFA method to their account
    # @param [Boolean] success
    def mfa_enroll_webauthn_roaming(success:)
      track_event(
        :mfa_enroll_webauthn_roaming,
        success: success,
      )
    end

    # Tracks when the user has attempted to verify the Backup Codes MFA method to their account
    # @param [Boolean] success
    def mfa_verify_backup_code(success:)
      track_event(
        :mfa_verify_backup_code,
        success: success,
      )
    end

    # @param [Boolean] reauthentication - True if the user was already logged in
    # @param [String] phone_number - The user's phone_number used for multi-factor authentication
    # @param [Boolean] success - True if the OTP Verification was sent
    # During a login attempt, an OTP code has been sent via SMS.
    def mfa_verify_phone_otp_sent(reauthentication:, phone_number:, success:)
      track_event(
        :mfa_verify_phone_otp_sent,
        reauthentication: reauthentication,
        phone_number: phone_number,
        success: success,
      )
    end

    # @param [Boolean] success - True if the sms otp submitted matched what was sent
    # During a login attempt, the user, having previously been sent an OTP code via SMS
    # has entered an OTP code.
    def mfa_verify_phone_otp_submitted(reauthentication:, success:)
      track_event(
        :mfa_verify_phone_otp_submitted,
        reauthentication: reauthentication,
        success: success,
      )
    end

    # Tracks when the user has attempted to verify via the TOTP MFA method to access their account
    # @param [Boolean] success
    def mfa_verify_totp(success:)
      track_event(
        :mfa_verify_totp,
        success: success,
      )
    end

    # Tracks when user has attempted to verify via the WebAuthn-Platform MFA method to their account
    # @param [Boolean] success
    def mfa_verify_webauthn_platform(success:)
      track_event(
        :mfa_verify_webauthn_platform,
        success: success,
      )
    end

    # Tracks when the user has attempted to verify via the WebAuthn MFA method to their account
    # @param [Boolean] success
    def mfa_verify_webauthn_roaming(success:)
      track_event(
        :mfa_verify_webauthn_roaming,
        success: success,
      )
    end

    # Tracks when the user has attempted to enroll the piv cac MFA method to their account
    # @param [String] subject_dn
    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def mfa_enroll_piv_cac(
      success:,
      subject_dn: nil,
      failure_reason: nil
    )
      track_event(
        :mfa_enroll_piv_cac,
        success: success,
        subject_dn: subject_dn,
        failure_reason: failure_reason,
      )
    end

    # Tracks when the user has attempted to verify the piv cac MFA method to their account
    # @param [String] subject_dn
    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def mfa_login_piv_cac(
      success:,
      subject_dn: nil,
      failure_reason: nil
    )
      track_event(
        :mfa_login_piv_cac,
        success: success,
        subject_dn: subject_dn,
        failure_reason: failure_reason,
      )
    end

    # Tracks when user confirms registration email
    # @param [Boolean] success
    # @param [String] email
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def user_registration_email_confirmation(
      success:,
      email: nil,
      failure_reason: nil
    )
      track_event(
        :user_registration_email_confirmation,
        success: success,
        email: email,
        failure_reason: failure_reason,
      )
    end

    # Tracks when user submits registration email
    # @param [Boolean] success
    # @param [String] email
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def user_registration_email_submitted(
      success:,
      email:,
      failure_reason: nil
    )
      track_event(
        :user_registration_email_submitted,
        success: success,
        email: email,
        failure_reason: failure_reason,
      )
    end

    # Tracks when user submits registration password
    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def user_registration_password_submitted(
      success:,
      failure_reason: nil
    )
      track_event(
        :user_registration_password_submitted,
        success: success,
        failure_reason: failure_reason,
      )
    end
  end
end
