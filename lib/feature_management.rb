class FeatureManagement
  ENVS_WHERE_PREFILLING_USPS_CODE_ALLOWED = %w[
    idp.dev.login.gov idp.int.login.gov idp.qa.login.gov idp.pt.login.gov
    idp.dev.identitysandbox.gov idp.qa.identitysandbox.gov idp.int.identitysandbox.gov
    idp.pt.identitysandbox.gov
  ].freeze

  def self.telephony_test_adapter?
    Figaro.env.telephony_adapter.blank? || Figaro.env.telephony_adapter == 'test'
  end

  def self.identity_pki_disabled?
    env = Figaro.env
    env.identity_pki_disabled == 'true' ||
      !env.piv_cac_service_url ||
      !env.piv_cac_verify_token_url
  end

  def self.allow_piv_cac_login?
    Figaro.env.login_with_piv_cac == 'true'
  end

  def self.development_and_identity_pki_disabled?
    # This controls if we try to hop over to identity-pki or just throw up
    # a screen asking for a Subject or one of a list of error conditions.
    Rails.env.development? && identity_pki_disabled?
  end

  def self.prefill_otp_codes?
    # In development, when SMS is disabled we pre-fill the correct codes so that
    # developers can log in without needing to configure SMS delivery.
    # We also allow this in production on a single server that is used for load testing.
    development_and_telephony_test_adapter? || prefill_otp_codes_allowed_in_sandbox?
  end

  def self.development_and_telephony_test_adapter?
    Rails.env.development? && telephony_test_adapter?
  end

  def self.prefill_otp_codes_allowed_in_sandbox?
    LoginGov::Hostdata.domain == 'identitysandbox.gov' && telephony_test_adapter?
  end

  def self.enable_load_testing_mode?
    Figaro.env.enable_load_testing_mode == 'true'
  end

  def self.use_kms?
    Figaro.env.use_kms == 'true'
  end

  def self.kms_multi_region_enabled?
    Figaro.env.aws_kms_multi_region_enabled == 'true'
  end

  def self.use_dashboard_service_providers?
    Figaro.env.use_dashboard_service_providers == 'true'
  end

  def self.enable_usps_verification?
    Figaro.env.enable_usps_verification == 'true'
  end

  def self.reveal_usps_code?
    Rails.env.development? || current_env_allowed_to_see_usps_code?
  end

  def self.current_env_allowed_to_see_usps_code?
    ENVS_WHERE_PREFILLING_USPS_CODE_ALLOWED.include?(Figaro.env.domain_name)
  end

  def self.fake_banner_mode?
    Rails.env.production? && LoginGov::Hostdata.domain != 'login.gov'
  end

  def self.enable_saml_cert_rotation?
    Figaro.env.saml_secret_rotation_enabled == 'true'
  end

  def self.recaptcha_enabled?(session, reset)
    AbTest.new(:ab_test_recaptcha_enabled, Figaro.env.recaptcha_enabled_percent).
      enabled?(session, reset)
  end

  def self.disallow_all_web_crawlers?
    Figaro.env.disallow_all_web_crawlers == 'true'
  end

  def self.disallow_ial2_recovery?
    Figaro.env.disallow_ial2_recovery == 'true'
  end

  def self.backup_codes_as_only_2fa?
    Figaro.env.backup_codes_as_only_2fa == 'true'
  end

  def self.in_person_proofing_enabled?
    Figaro.env.in_person_proofing_enabled == 'true'
  end

  def self.usps_upload_enabled?
    Figaro.env.usps_upload_enabled == 'true'
  end

  def self.identity_pki_local_dev?
    # This option should only be used in the development environment
    # it controls if we hop over to identity-pki on a developers local machins
    Rails.env.development? && Figaro.env.identity_pki_local_dev == 'true'
  end

  def self.doc_capture_polling_enabled?
    Figaro.env.doc_capture_polling_enabled == 'true'
  end

  def self.document_capture_step_enabled?
    Figaro.env.document_capture_step_enabled == 'true'
  end

  def self.document_capture_async_uploads_enabled?
    Figaro.env.doc_auth_enable_presigned_s3_urls == 'true'
  end

  def self.hide_phone_mfa_signup?
    Figaro.env.hide_phone_mfa_signup == 'true'
  end

  def self.liveness_checking_enabled?
    Figaro.env.liveness_checking_enabled == 'true'
  end

  def self.logo_upload_enabled?
    Figaro.env.logo_upload_enabled == 'true'
  end

  def self.log_to_stdout?
    !Rails.env.test? && Figaro.env.log_to_stdout == 'true'
  end
end
