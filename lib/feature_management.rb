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

  def self.idv_available?
    return false if !IdentityConfig.store.idv_available
    !OutageStatus.new.any_idv_vendor_outage?
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

  def self.use_dashboard_service_providers?
    IdentityConfig.store.use_dashboard_service_providers
  end

  def self.gpo_verification_enabled?
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

  def self.logo_upload_enabled?
    IdentityConfig.store.logo_upload_enabled
  end

  def self.log_to_stdout?
    !Rails.env.test? && IdentityConfig.store.log_to_stdout
  end

  def self.phone_recaptcha_enabled?
    return false if IdentityConfig.store.recaptcha_site_key_v2.blank? ||
                    IdentityConfig.store.recaptcha_site_key_v3.blank? ||
                    !IdentityConfig.store.phone_recaptcha_score_threshold.positive?

    recaptcha_enterprise? || (
      IdentityConfig.store.recaptcha_secret_key_v2.present? &&
      IdentityConfig.store.recaptcha_secret_key_v3.present?
    )
  end

  def self.recaptcha_enterprise?
    IdentityConfig.store.recaptcha_enterprise_api_key.present? &&
      IdentityConfig.store.recaptcha_enterprise_project_id.present?
  end

  # Manual allowlist for VOIPs, should only include known VOIPs that we use for smoke tests
  # @return [Set<String>] set of phone numbers normalized to e164
  def self.voip_allowed_phones
    @voip_allowed_phones ||= begin
      allowed_phones = IdentityConfig.store.voip_allowed_phones
      allowed_phones.map { |p| Phonelib.parse(p).e164 }.to_set
    end
  end

  # Whether we collect device profiling information as part of the proofing process.
  def self.proofing_device_profiling_collecting_enabled?
    case IdentityConfig.store.proofing_device_profiling
    when :enabled, :collect_only then true
    when :disabled then false
    else
      raise 'Invalid value for proofing_device_profiling'
    end
  end

  # Whether we prevent users from proceeding with identity verification based on the outcomes of
  # device profiling.
  def self.proofing_device_profiling_decisioning_enabled?
    case IdentityConfig.store.proofing_device_profiling
    when :enabled then true
    when :collect_only, :disabled then false
    else
      raise 'Invalid value for proofing_device_profiling'
    end
  end

  # Whether or not idv hybrid mode is available
  def self.idv_allow_hybrid_flow?
    return false unless IdentityConfig.store.feature_idv_hybrid_flow_enabled
    return false if OutageStatus.new.any_phone_vendor_outage?
    true
  end

  def self.idv_gpo_only?
    outage_status = OutageStatus.new
    IdentityConfig.store.feature_idv_force_gpo_verification_enabled ||
      outage_status.any_phone_vendor_outage? ||
      outage_status.phone_finder_outage?
  end
end
