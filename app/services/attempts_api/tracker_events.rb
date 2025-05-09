# frozen_string_literal: true

module AttemptsApi
  module TrackerEvents
    # @param [Boolean] success True if account successfully deleted
    # @param [Hash<Key, Array<String>>] failure_reason displays why account deletion failed
    # Account was successfully deleted after the account reset request was completed
    def account_reset_account_deleted(success:, failure_reason: nil)
      track_event(
        'account-reset-account-deleted',
        success:,
        failure_reason:,
      )
    end

    # @param [Boolean] success True if the email and password matched
    # A user has submitted an email address and password for authentication
    def email_and_password_auth(success:)
      track_event(
        'login-email-and-password-auth',
        success:,
      )
    end

    # @param [Boolean] success True if the images were successfully uploaded
    # @param [String] document_back_image_encryption_key Base64-encoded AES key used for back
    # @param [String] document_back_image_file_id Filename in S3 w/encrypted data for back image
    # @param [String] document_front_image_encryption_key Base64-encoded AES key used for front
    # @param [String] document_front_image_file_id Filename in S3 w/encrypted data for front image
    # @param [String] document_selfie_image_encryption_key Base64-encoded AES key used for selfiet
    # @param [String] document_selfie_image_file_id Filename in S3 w/encrypted data for selfie image
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason if password was not successfully changed
    # A user has uploaded documents locally
    def idv_document_uploaded(
        success:,
        document_back_image_encryption_key:,
        document_back_image_file_id:,
        document_front_image_encryption_key:,
        document_front_image_file_id:,
        document_selfie_image_encryption_key:,
        document_selfie_image_file_id:,
        failure_reason: nil
      )
      track_event(
        'idv-document-uploaded',
        success:,
        failure_reason:,
        document_back_image_encryption_key:,
        document_back_image_file_id:,
        document_front_image_encryption_key:,
        document_front_image_file_id:,
        document_selfie_image_encryption_key:,
        document_selfie_image_file_id:,
      )
    end

    # @param [Boolean] success True if the link user clicked on is valid and not expired
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # A user clicks the email link to reset their password
    def forgot_password_email_confirmed(success:, failure_reason: nil)
      track_event(
        'forgot-password-email-confirmed',
        success:,
        failure_reason:,
      )
    end

    # @param [String] email The user's email address
    #  A user has requested a password reset.
    def forgot_password_email_sent(email:)
      track_event(
        'forgot-password-email-sent',
        email:,
      )
    end

    # @param [Boolean] success True if new password was successfully submitted
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # A user submits a new password have requesting a password reset
    def forgot_password_new_password_submitted(success:, failure_reason: nil)
      track_event(
        'forgot-password-new-password-submitted',
        success:,
        failure_reason:,
      )
    end

    # @param [Boolean] reproof True indicates that the user has proofed previously
    # A user has completed the identity verification process and has an active profile
    def idv_enrollment_complete(reproof:)
      track_event(
        'idv-enrollment-complete',
        reproof:,
      )
    end

    # A user becomes able to visit the post office for in-person proofing
    def idv_ipp_ready_to_verify_visit
      track_event('idv-ipp-ready-to-verify-visit')
    end

    # @param [Boolean] success True if the entered code matched the sent code
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason if code did not match
    # A user that requested to verify their address by mail entered the code contained in the letter
    def idv_verify_by_mail_enter_code_submitted(success:, failure_reason: nil)
      track_event(
        'idv-verify-by-mail-enter-code-submitted',
        success:,
        failure_reason:,
      )
    end

    # @param [Boolean] success
    # @param [String] phone_number
    # @param [String<':sms',':voice'>] otp_delivery_method
    # @param [Hash<Key, Array<String>>] failure_reason
    # OTP is sent and what method chosen during idv flow.
    def idv_phone_otp_sent(success:, phone_number:,
                           otp_delivery_method:, failure_reason: nil)
      track_event(
        'idv-phone-otp-sent',
        success:,
        phone_number:,
        otp_delivery_method:,
        failure_reason:,
      )
    end

    # @param [Boolean] success
    # @param [String] phone_number
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # User submits OTP code sent to their phone
    def idv_phone_otp_submitted(phone_number:, success:, failure_reason: nil)
      track_event(
        'idv-phone-otp-submitted',
        success:,
        phone_number:,
        failure_reason:,
      )
    end

    # @param [Boolean] success
    # @param [String] phone_number
    # @param [Hash<Key, Array<String>>] failure_reason
    # The user provides their phone number for identity verification
    def idv_phone_submitted(success:, phone_number:, failure_reason: nil)
      track_event(
        'idv-phone-submitted',
        success:,
        phone_number:,
        failure_reason:,
      )
    end

    # @param [Boolean] resend False indicates this is the initial request
    # User has requested the Address validation letter
    def idv_verify_by_mail_letter_requested(resend:)
      track_event(
        'idv-verify-by-mail-letter-requested',
        resend:,
      )
    end

    # The user, who had previously successfully confirmed their identity, has
    # reproofed. All the normal events are also sent, this simply notes that
    # this is the second (or more) time they have gone through the process successfully.
    def idv_reproof
      track_event('idv-reproof')
    end

    # The user has exceeded the rate limit during idv document upload
    # @param limiter_type [String<'idv_doc_auth', 'idv_resolution', 'proof_ssn', 'proof_address',
    #   'confirmation', 'idv_send_link']
    #  Type of rate limit
    def idv_rate_limited(limiter_type:)
      track_event(
        'idv-rate-limited',
        limiter_type:,
      )
    end

    # @param [Boolean] success True if account successfully deleted
    # A User deletes their Login.gov account
    def logged_in_account_purged(success:)
      track_event(
        'logged-in-account-purged',
        success:,
      )
    end

    # @param [Boolean] success True if the password was successfully changed
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason if password was not successfully changed
    # A logged-in user has attempted to change their password
    def logged_in_password_change(success:, failure_reason: nil)
      track_event(
        'logged-in-password-change',
        success:,
        failure_reason:,
      )
    end

    # A user has successfully logged in and is being handed off to integration
    def login_completed
      track_event('login-completed')
    end

    # @param [Boolean] success
    # A user has initiated a logout event
    def logout_initiated(success:)
      track_event(
        'logout-initiated',
        success:,
      )
    end

    # Tracks when user enrolls their MFA device.
    # @param [Boolean] success
    # @param mfa_device_type [String<'backup_code', 'otp', 'personal_key', 'piv_cac',
    # 'remember_device', 'totp', 'webauthn', 'webauthn_platform'>]
    # @param [String<'sms','voice'>] otp_delivery_method
    # @param [String] phone_number Enrolled phone number
    def mfa_enrolled(success:, mfa_device_type:, otp_delivery_method: nil, phone_number: nil)
      track_event(
        'mfa-enrolled',
        success:,
        mfa_device_type:,
        otp_delivery_method:,
        phone_number:,
      )
    end

    # Tracks when user submits registration password
    # @param [String<'backup_code', 'otp', 'piv_cac', 'totp'>] mfa_device_type
    # The user has exceeded the rate limit during enrollment
    # and account has been locked
    def mfa_enroll_code_rate_limited(mfa_device_type:)
      track_event(
        'mfa-enroll-code-rate-limited',
        mfa_device_type:,
      )
    end

    # @param [String] phone_number - The user's phone number used for multi-factor authentication
    # The user has exceeded the rate limit for SMS OTP sends during mfa enrollment.
    def mfa_enroll_phone_otp_sent_rate_limited(phone_number:)
      track_event(
        'mfa-enroll-phone-otp-sent-rate-limited',
        phone_number:,
      )
    end

    # Tracks when user submits a verification attempt using their MFA.
    # @param mfa_device_type [String<'backup_code', 'otp', 'personal_key', 'piv_cac',
    # 'remember_device', 'totp', 'webauthn', 'webauthn_platform'>]
    # @param [Boolean] reauthentication
    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def mfa_login_auth_submitted(mfa_device_type:, reauthentication:, success:, failure_reason: nil)
      track_event(
        'mfa-login-auth-submitted',
        mfa_device_type:,
        reauthentication:,
        success:,
        failure_reason:,
      )
    end

    # @param [String] phone_number - The user's phone number used for multi-factor authentication
    # The user has exceeded the rate limit for SMS OTP sends during login attempt.
    def mfa_login_phone_otp_sent_rate_limited(phone_number:)
      track_event(
        'mfa-login-phone-otp-sent-rate-limited',
        phone_number:,
      )
    end

    # @param [String<'backup_code', 'otp', 'piv_cac', 'totp', 'personal_key'>] mfa_device_type
    # The user has exceeded the rate limit during verification
    # and account has been locked
    def mfa_submission_code_rate_limited(mfa_device_type:)
      track_event(
        'mfa-submission-code-rate-limited',
        mfa_device_type:,
      )
    end

    # @param [Boolean] success True means TMX check has a 'pass' review status
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # Tracks the result of the TMX fraud check during Identity Verification
    def idv_tmx_fraud_check(success:, failure_reason: nil)
      track_event(
        'idv-tmx-fraud-check',
        success:,
        failure_reason:,
      )
    end

    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # Tracks when user submits registration password
    def user_registration_password_submitted(
      success:,
      failure_reason: nil
    )
      track_event(
        'user-registration-password-submitted',
        success:,
        failure_reason:,
      )
    end
  end
end
