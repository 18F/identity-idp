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

    # @param [String] user_uuid The user's uuid
    # @param [String] unique_session_id The unique session id
    # @param [Boolean] success True if the email and password matched
    # A user has initiated a logout event
    def logout_initiated(success:)
      track_event(
        :logout_initiated,
        success: success,
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

    # Tracks when the user has attempted to enroll the TOTP MFA method to their account
    # @param [Boolean] success
    def mfa_enroll_totp(success:)
      track_event(
        :mfa_enroll_totp,
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

    # Tracks when the user has attempted to verify via the TOTP MFA method to access their account
    # @param [Boolean] success
    def mfa_verify_totp(success:)
      track_event(
        :mfa_verify_totp,
        success: success,
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
  end
end
