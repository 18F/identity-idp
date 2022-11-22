# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module IrsAttemptsApi
  module TrackerEvents
    # @param [Boolean] success True if Account Successfully Deleted
    # @param [Hash<Key, Array<String>>] failure_reason displays why account deletion failed
    # A User confirms and deletes their Login.gov account after 24 hour period
    def account_reset_account_deleted(success:, failure_reason: nil)
      track_event(
        :account_reset_account_deleted,
        success: success,
        failure_reason: failure_reason,
      )
    end

    # A user cancels the request to delete their account before 24 hour period
    def account_reset_cancel_request
      track_event(
        :account_reset_cancel_request,
      )
    end

    # @param [Boolean] success True if Account Reset Deletion submitted successful
    # account Reset Deletion Requested
    def account_reset_request_submitted(success:)
      track_event(
        :account_reset_request_submitted,
        success: success,
      )
    end

    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def forgot_password_email_confirmed(success:, failure_reason: nil)
      track_event(
        :forgot_password_email_confirmed,
        success: success,
        failure_reason: failure_reason,
      )
    end

    # The user has exceeded the rate limit for password reset emails
    # @param [String] email The user's email address
    def forgot_password_email_rate_limited(email:)
      track_event(
        :forgot_password_email_rate_limited,
        email: email,
      )
    end

    # Tracks when the user has requested a forgot password email
    # @param [String] email The submitted email address
    def forgot_password_email_sent(email:)
      track_event(
        :forgot_password_email_sent,
        email: email,
      )
    end

    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def forgot_password_new_password_submitted(success:, failure_reason: nil)
      track_event(
        :forgot_password_new_password_submitted,
        success: success,
        failure_reason: failure_reason,
      )
    end

    # @param ["mobile", "desktop"] upload_method method chosen for uploading id verification
    # A user has selected id document upload method
    def idv_document_upload_method_selected(upload_method:)
      track_event(
        :idv_document_upload_method_selected,
        upload_method: upload_method,
      )
    end

    # The user has exceeded the rate limit during idv document upload
    def idv_document_upload_rate_limited
      track_event(
        :idv_document_upload_rate_limited,
      )
    end

    # @param [Boolean] success
    # @param [String] document_state
    # @param [String] document_number
    # @param [String] document_issued
    # @param [String] document_expiration
    # @param [String] front_image_uuid
    # @param [String] front_image_content_type
    # @param [String] front_image_encryption_key
    # @param [String] back_image_uuid
    # @param [String] back_image_content_type
    # @param [String] back_image_encryption_key
    # @param [String] first_name
    # @param [String] last_name
    # @param [String] date_of_birth
    # @param [String] address
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # The document was uploaded during the IDV process
    def idv_document_upload_submitted(
      success:,
      document_state: nil,
      document_number: nil,
      document_issued: nil,
      document_expiration: nil,
      front_image_uuid: nil,
      front_image_content_type: nil,
      front_image_encryption_key: nil,
      back_image_uuid: nil,
      back_image_content_type: nil,
      back_image_encryption_key: nil,
      first_name: nil,
      last_name: nil,
      date_of_birth: nil,
      address: nil,
      failure_reason: nil
    )
      track_event(
        :idv_document_upload_submitted,
        success: success,
        document_state: document_state,
        document_number: document_number,
        document_issued: document_issued,
        document_expiration: document_expiration,
        front_image_uuid: front_image_uuid,
        front_image_content_type: front_image_content_type,
        front_image_encryption_key: front_image_encryption_key,
        back_image_uuid: back_image_uuid,
        back_image_content_type: back_image_content_type,
        back_image_encryption_key: back_image_encryption_key,
        first_name: first_name,
        last_name: last_name,
        date_of_birth: date_of_birth,
        address: address,
        failure_reason: failure_reason,
      )
    end

    # @param [String] resend
    # The Address validation letter has been requested by user
    def idv_gpo_letter_requested(resend:)
      track_event(
        :idv_gpo_letter_requested,
        resend: resend,
      )
    end

    # GPO verification submission rate limited, user entered in too many invalid gpo letter codes
    def idv_gpo_verification_rate_limited
      track_event(
        :idv_gpo_verification_rate_limited,
      )
    end

    # @param [Boolean] success
    # @param [Hash<Key, Array<String>>] failure_reason displays GPO submission failed
    # GPO verification submitted from Letter sent to verify address
    def idv_gpo_verification_submitted(success:, failure_reason: nil)
      track_event(
        :idv_gpo_verification_submitted,
        success: success,
        failure_reason: failure_reason,
      )
    end

    # Tracks when the user submits a password for identity proofing
    # @param [Boolean] success
    def idv_password_entered(success:)
      track_event(
        :idv_password_entered,
        success: success,
      )
    end

    # Personal Key got generated for user
    def idv_personal_key_generated
      track_event(
        :idv_personal_key_generated,
      )
    end

    # @param [Boolean] success
    # @param [String] phone_number
    # @param [String] otp_delivery_method - Either SMS or Voice
    # @param [Hash<Key, Array<String>>] failure_reason
    # Track when OTP is sent and what method chosen during idv flow.
    def idv_phone_otp_sent(success:, phone_number:, otp_delivery_method:, failure_reason: nil)
      track_event(
        :idv_phone_otp_sent,
        success: success,
        phone_number: phone_number,
        otp_delivery_method: otp_delivery_method,
        failure_reason: failure_reason,
      )
    end

    # Tracks Idv phone OTP sent rate limits
    def idv_phone_otp_sent_rate_limited
      track_event(
        :idv_phone_otp_sent_rate_limited,
      )
    end

    # Tracks when a user submits OTP code sent to their phone
    # @param [Boolean] success
    # @param [String] phone_number
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def idv_phone_otp_submitted(success:, phone_number:, failure_reason: nil)
      track_event(
        :idv_phone_otp_submitted,
        success: success,
        phone_number: phone_number,
        failure_reason: failure_reason,
      )
    end

    # The user reached the rate limit for Idv phone OTP submitted
    # @param [String] phone_number
    def idv_phone_otp_submitted_rate_limited(phone_number:)
      track_event(
        :idv_phone_otp_submitted_rate_limited,
        phone_number: phone_number,
      )
    end

    # Tracks when sending a link to a phone is rate limited during idv flow
    # @param [String] phone_number
    def idv_phone_send_link_rate_limited(phone_number:)
      track_event(
        :idv_phone_send_link_rate_limited,
        phone_number: phone_number,
      )
    end

    # Tracks when the user submits their idv phone number
    # @param [Boolean] success
    # @param [String] phone_number
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def idv_phone_submitted(success:, phone_number:, failure_reason: nil)
      track_event(
        :idv_phone_submitted,
        success: success,
        phone_number: phone_number,
        failure_reason: failure_reason,
      )
    end

    # @param [Boolean] success
    # @param [String] phone_number
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # The phone number that the link was sent to during the IDV process
    def idv_phone_upload_link_sent(
      success:,
      phone_number:,
      failure_reason: nil
    )
      track_event(
        :idv_phone_upload_link_sent,
        success: success,
        phone_number: phone_number,
        failure_reason: failure_reason,
      )
    end

    # The user has used a phone_upload_link to upload docs on their mobile device
    def idv_phone_upload_link_used
      track_event(
        :idv_phone_upload_link_used,
      )
    end

    # The user, who had previously successfully confirmed their identity, has
    # reproofed. All the normal events are also sent, this simply notes that
    # this is the second (or more) time they have gone through the process successfully.
    def idv_reproof
      track_event(
        :idv_reproof,
      )
    end

    # @param [String] ssn
    # User entered in SSN number during Identity verification
    def idv_ssn_submitted(ssn:)
      track_event(
        :idv_ssn_submitted,
        ssn: ssn,
      )
    end

    # Track when idv verification is rate limited during idv flow
    def idv_verification_rate_limited
      track_event(
        :idv_verification_rate_limited,
      )
    end

    # @param [Boolean] success
    # @param [String] document_state
    # @param [String] document_number
    # @param [String] document_issued
    # @param [String] document_expiration
    # @param [String] first_name
    # @param [String] last_name
    # @param [String] date_of_birth
    # @param [String] address
    # @param [String] ssn
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # The verification was submitted during the IDV process
    def idv_verification_submitted(
      success:,
      document_state: nil,
      document_number: nil,
      document_issued: nil,
      document_expiration: nil,
      first_name: nil,
      last_name: nil,
      date_of_birth: nil,
      address: nil,
      ssn: nil,
      failure_reason: nil
    )
      track_event(
        :idv_verification_submitted,
        success: success,
        document_state: document_state,
        document_number: document_number,
        document_issued: document_issued,
        document_expiration: document_expiration,
        first_name: first_name,
        last_name: last_name,
        date_of_birth: date_of_birth,
        address: address,
        ssn: ssn,
        failure_reason: failure_reason,
      )
    end

    # @param [Boolean] success True if Account Successfully Deleted
    # A User deletes their Login.gov account
    def logged_in_account_purged(success:)
      track_event(
        :logged_in_account_purged,
        success: success,
      )
    end

    # @param [Boolean] success True if the password was successfully changed
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # A logged-in user has attempted to change their password
    def logged_in_password_change(success:, failure_reason: nil)
      track_event(
        :logged_in_password_change,
        success: success,
        failure_reason: failure_reason,
      )
    end

    # A logged-in user has been rate limited from submitting a password to reauthenticate prior to
    # changing their profile too many times
    def logged_in_profile_change_reauthentication_rate_limited
      track_event(
        :logged_in_profile_change_reauthentication_rate_limited,
      )
    end

    # @param [Boolean] success True if the password submitted for reauthentication matches the
    # current password
    # A logged-in user has submitted a password to reauthenticate prior to changing their profile
    def logged_in_profile_change_reauthentication_submitted(success:)
      track_event(
        :logged_in_profile_change_reauthentication_submitted,
        success: success,
      )
    end

    # @param [String] email The submitted email address
    # @param [Boolean] success True if the email and password matched
    # A user has submitted an email address and password for authentication
    def login_email_and_password_auth(email:, success:)
      track_event(
        :login_email_and_password_auth,
        email: email,
        success: success,
      )
    end

    # @param [String] email
    # A login attempt was rejected due to too many incorrect attempts
    def login_rate_limited(email:)
      track_event(
        :login_rate_limited,
        email: email,
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

    # Tracks when the user has attempted to enroll the Backup Codes MFA method to their account
    # @param [Boolean] success
    def mfa_enroll_backup_code(success:)
      track_event(
        :mfa_enroll_backup_code,
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

    # @param [Boolean] success - True if the OTP Verification was sent
    # @param [String] phone_number - The user's phone_number used for multi-factor authentication
    # @param [String] otp_delivery_method - Either SMS or Voice
    # Relevant only when the user is enrolling a phone as their MFA.
    # The user has been sent an OTP and by SMS or Voice during the MFA enrollment process.
    def mfa_enroll_phone_otp_sent(success:, phone_number:, otp_delivery_method:)
      track_event(
        :mfa_enroll_phone_otp_sent,
        success: success,
        phone_number: phone_number,
        otp_delivery_method: otp_delivery_method,
      )
    end

    # @param [String] phone_number - The user's phone number used for multi-factor authentication
    # The user has exceeded the rate limit for SMS OTP sends.
    def mfa_enroll_phone_otp_sent_rate_limited(phone_number:)
      track_event(
        :mfa_enroll_phone_otp_sent_rate_limited,
        phone_number: phone_number,
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

    # Tracks when the user has attempted to enroll the piv cac MFA method to their account
    # @param [Boolean] success
    # @param [String] subject_dn
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

    # @param [String] mfa_device_type - the type of multi-factor authentication used
    # The user has exceeded the rate limit during enrollment
    # and account has been locked
    def mfa_enroll_rate_limited(mfa_device_type:)
      track_event(
        :mfa_enroll_rate_limited,
        mfa_device_type: mfa_device_type,
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

    # Tracks when the user has attempted to log in with the Backup Codes MFA method to their account
    # @param [Boolean] success
    def mfa_login_backup_code(success:)
      track_event(
        :mfa_login_backup_code,
        success: success,
      )
    end

    # @param [Boolean] success - True if the OTP Verification was sent
    # @param [Boolean] reauthentication - True if the user was already logged in
    # @param [String] phone_number - The user's phone_number used for multi-factor authentication
    # @param [String] otp_delivery_method - Either SMS or Voice
    # During a login attempt, an OTP code has been sent via SMS or Voice.
    def mfa_login_phone_otp_sent(success:, reauthentication:, phone_number:, otp_delivery_method:)
      track_event(
        :mfa_login_phone_otp_sent,
        success: success,
        reauthentication: reauthentication,
        phone_number: phone_number,
        otp_delivery_method: otp_delivery_method,
      )
    end

    # @param [String] phone_number - The user's phone number used for multi-factor authentication
    # The user has exceeded the rate limit for SMS OTP sends.
    def mfa_login_phone_otp_sent_rate_limited(phone_number:)
      track_event(
        :mfa_login_phone_otp_sent_rate_limited,
        phone_number: phone_number,
      )
    end

    # @param [Boolean] reauthentication if the user was already logged in
    # @param [Boolean] success True if the sms otp submitted matched what was sent
    # During a login attempt, the user, having previously been sent an OTP code via SMS
    # has entered an OTP code.
    def mfa_login_phone_otp_submitted(reauthentication:, success:)
      track_event(
        :mfa_login_phone_otp_submitted,
        reauthentication: reauthentication,
        success: success,
      )
    end

    # Tracks when the user has attempted to log in with the piv cac MFA method to their account
    # @param [Boolean] success
    # @param [String] subject_dn
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

    # @param [String] mfa_device_type - the type of multi-factor authentication used
    # The user has exceeded the rate limit during verification
    # and account has been locked
    def mfa_login_rate_limited(mfa_device_type:)
      track_event(
        :mfa_login_rate_limited,
        mfa_device_type: mfa_device_type,
      )
    end

    # Tracks when the user has attempted to log in with the TOTP MFA method to access their account
    # @param [Boolean] success
    def mfa_login_totp(success:)
      track_event(
        :mfa_login_totp,
        success: success,
      )
    end

    # Tracks when user has attempted to log in with WebAuthn-Platform MFA method to their account
    # @param [Boolean] success
    def mfa_login_webauthn_platform(success:)
      track_event(
        :mfa_login_webauthn_platform,
        success: success,
      )
    end

    # Tracks when the user has attempted to log in with the WebAuthn MFA method to their account
    # @param [Boolean] success
    def mfa_login_webauthn_roaming(success:)
      track_event(
        :mfa_login_webauthn_roaming,
        success: success,
      )
    end

    # Tracks when User personal key has been rate limited by too many attempts
    def personal_key_reactivation_rate_limited
      track_event(
        :personal_key_reactivation_rate_limited,
      )
    end

    # Tracks when user has entered personal key after forgot password steps
    # @param [Boolean] success
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    def personal_key_reactivation_submitted(success:, failure_reason: nil)
      track_event(
        :personal_key_reactivation_submitted,
        success: success,
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

    # Tracks when user is rate limited for submitting registration email
    # @param [String] email
    # @param [Boolean] email_already_registered
    def user_registration_email_submission_rate_limited(
      email:,
      email_already_registered:
    )
      track_event(
        :user_registration_email_submission_rate_limited,
        email: email,
        email_already_registered: email_already_registered,
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
# rubocop:enable Metrics/ModuleLength
