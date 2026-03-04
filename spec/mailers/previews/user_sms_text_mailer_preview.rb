class UserSmsTextMailerPreview < ActionMailer::Preview
  delegate :account_deleted_notice,
           :account_deletion_started,
           :account_deletion_cancelled,
           :authentication_otp,
           :confirmation_ipp_enrollment_result,
           :confirmation_otp,
           :daily_voice_limit_reached,
           :doc_auth_link,
           :duplicate_profile_created,
           :duplicate_profile_sign_in_attempted,
           :personal_key_regeneration_notice,
           :personal_key_sign_in_notice,
           to: UserSmsTextMailer
end
