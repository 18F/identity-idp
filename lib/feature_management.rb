class FeatureManagement
  ENVS_WHERE_PREFILLING_GPO_CODE_ALLOWED = %w[
    idp.dev.login.gov idp.int.login.gov idp.qa.login.gov idp.pt.login.gov
    idp.dev.identitysandbox.gov idp.qa.identitysandbox.gov idp.int.identitysandbox.gov
    idp.pt.identitysandbox.gov
  ].freeze

  def self.telephony_test_adapter?
    IdentityConfig.store.telephony_adapter == 'test'
  end

  def self.identity_pki_disabled?
    IdentityConfig.store.identity_pki_disabled ||
      !IdentityConfig.store.piv_cac_service_url ||
      !IdentityConfig.store.piv_cac_verify_token_url
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
    IdentityConfig.store.enable_load_testing_mode
  end

  def self.use_kms?
    IdentityConfig.store.use_kms
  end

  def self.kms_multi_region_enabled?
    IdentityConfig.store.aws_kms_multi_region_enabled
  end

  def self.use_dashboard_service_providers?
    IdentityConfig.store.use_dashboard_service_providers
  end

  def self.enable_gpo_verification?
    # leaving the usps name for backwards compatibility
    IdentityConfig.store.enable_usps_verification
  end

  def self.reveal_gpo_code?
    Rails.env.development? || current_env_allowed_to_see_gpo_code?
  end

  def self.current_env_allowed_to_see_gpo_code?
    ENVS_WHERE_PREFILLING_GPO_CODE_ALLOWED.include?(IdentityConfig.store.domain_name)
  end

  def self.show_demo_banner?
    Identity::Hostdata.in_datacenter? && Identity::Hostdata.env != 'prod'
  end

  def self.show_no_pii_banner?
    Identity::Hostdata.in_datacenter? && Identity::Hostdata.domain != 'login.gov'
  end

  def self.enable_saml_cert_rotation?
    IdentityConfig.store.saml_secret_rotation_enabled
  end

  def self.disallow_all_web_crawlers?
    IdentityConfig.store.disallow_all_web_crawlers
  end

  def self.gpo_upload_enabled?
    # leaving the usps name for backwards compatibility
    IdentityConfig.store.usps_upload_enabled
  end

  def self.identity_pki_local_dev?
    # This option should only be used in the development environment
    # it controls if we hop over to identity-pki on a developers local machins
    Rails.env.development? && IdentityConfig.store.identity_pki_local_dev
  end

  def self.doc_capture_polling_enabled?
    IdentityConfig.store.doc_capture_polling_enabled
  end

  def self.document_capture_async_uploads_enabled?
    IdentityConfig.store.doc_auth_enable_presigned_s3_urls
  end

  def self.liveness_checking_enabled?
    IdentityConfig.store.liveness_checking_enabled
  end

  def self.logo_upload_enabled?
    IdentityConfig.store.logo_upload_enabled
  end

  def self.log_to_stdout?
    !Rails.env.test? && IdentityConfig.store.log_to_stdout
  end

  # Manual allowlist for VOIPs, should only include known VOIPs that we use for smoke tests
  # @return [Set<String>] set of phone numbers normalized to e164
  def self.voip_allowed_phones
    @voip_allowed_phones ||= begin
      allowed_phones = IdentityConfig.store.voip_allowed_phones
      allowed_phones.map { |p| Phonelib.parse(p).e164 }.to_set
    end
  end
end
