class FeatureManagement
  ENVS_WHERE_PREFILLING_GPO_CODE_ALLOWED = %w[
    idp.dev.login.gov idp.int.login.gov idp.qa.login.gov idp.pt.login.gov
    idp.dev.identitysandbox.gov idp.qa.identitysandbox.gov idp.int.identitysandbox.gov
    idp.pt.identitysandbox.gov
  ].freeze

  def self.telephony_test_adapter?
    AppConfig.env.telephony_adapter.blank? || AppConfig.env.telephony_adapter == 'test'
  end

  def self.identity_pki_disabled?
    env = AppConfig.env
    env.identity_pki_disabled == 'true' ||
      !IdentityConfig.store.piv_cac_service_url ||
      !env.piv_cac_verify_token_url
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
    Identity::Hostdata.domain == 'identitysandbox.gov' && telephony_test_adapter?
  end

  def self.enable_load_testing_mode?
    AppConfig.env.enable_load_testing_mode == 'true'
  end

  def self.use_kms?
    AppConfig.env.use_kms == 'true'
  end

  def self.kms_multi_region_enabled?
    AppConfig.env.aws_kms_multi_region_enabled == 'true'
  end

  def self.use_dashboard_service_providers?
    AppConfig.env.use_dashboard_service_providers == 'true'
  end

  def self.enable_gpo_verification?
    # leaving the usps name for backwards compatibility
    AppConfig.env.enable_usps_verification == 'true'
  end

  def self.reveal_gpo_code?
    Rails.env.development? || current_env_allowed_to_see_gpo_code?
  end

  def self.current_env_allowed_to_see_gpo_code?
    ENVS_WHERE_PREFILLING_GPO_CODE_ALLOWED.include?(AppConfig.env.domain_name)
  end

  def self.show_demo_banner?
    Identity::Hostdata.in_datacenter? && Identity::Hostdata.env != 'prod'
  end

  def self.show_no_pii_banner?
    Identity::Hostdata.in_datacenter? && Identity::Hostdata.domain != 'login.gov'
  end

  def self.enable_saml_cert_rotation?
    AppConfig.env.saml_secret_rotation_enabled == 'true'
  end

  def self.recaptcha_enabled?(session, reset)
    AbTest.new(:ab_test_recaptcha_enabled, AppConfig.env.recaptcha_enabled_percent).
      enabled?(session, reset)
  end

  def self.disallow_all_web_crawlers?
    AppConfig.env.disallow_all_web_crawlers == 'true'
  end

  def self.disallow_ial2_recovery?
    AppConfig.env.disallow_ial2_recovery == 'true'
  end

  def self.backup_codes_as_only_2fa?
    AppConfig.env.backup_codes_as_only_2fa == 'true'
  end

  def self.gpo_upload_enabled?
    # leaving the usps name for backwards compatibility
    AppConfig.env.usps_upload_enabled == 'true'
  end

  def self.identity_pki_local_dev?
    # This option should only be used in the development environment
    # it controls if we hop over to identity-pki on a developers local machins
    Rails.env.development? && AppConfig.env.identity_pki_local_dev == 'true'
  end

  def self.doc_capture_polling_enabled?
    AppConfig.env.doc_capture_polling_enabled == 'true'
  end

  def self.document_capture_async_uploads_enabled?
    AppConfig.env.doc_auth_enable_presigned_s3_urls == 'true'
  end

  def self.hide_phone_mfa_signup?
    AppConfig.env.hide_phone_mfa_signup == 'true'
  end

  def self.liveness_checking_enabled?
    AppConfig.env.liveness_checking_enabled == 'true'
  end

  def self.logo_upload_enabled?
    AppConfig.env.logo_upload_enabled == 'true'
  end

  def self.log_to_stdout?
    !Rails.env.test? && AppConfig.env.log_to_stdout == 'true'
  end

  # Whether or not we can call the phone_info endpoint at all
  def self.voip_check?
    AppConfig.env.voip_check == 'true'
  end

  # Whether or not we should block VOIP phone numbers
  def self.voip_block?
    AppConfig.env.voip_block == 'true'
  end

  def self.ruby_workers_enabled?
    AppConfig.env.ruby_workers_enabled == 'true'
  end

  # Manual allowlist for VOIPs, should only include known VOIPs that we use for smoke tests
  # @return [Set<String>] set of phone numbers normalized to e164
  def self.voip_allowed_phones
    @voip_allowed_phones ||= if (allowed_phones = AppConfig.env.voip_allowed_phones).present?
      JSON.parse(allowed_phones).map { |p| Phonelib.parse(p).e164 }.to_set
    else
      Set.new
    end
  end
end
