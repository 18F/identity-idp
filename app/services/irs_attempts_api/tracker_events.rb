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

    # Tracks when the user has attempted to enroll the MFA method TOTP to their account
    # @param [Boolean] success
    def multi_factor_auth_enroll_totp(success:)
      track_event(
        :totp_enroll,
        success: success,
      )
    end

    # Tracks when the user has attempted to verify via the TOTP MFA method to access their account
    # @param [Boolean] success
    def multi_factor_auth_verify_totp(success:)
      track_event(
        :totp_verify,
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
