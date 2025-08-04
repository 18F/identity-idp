# frozen_string_literal: true

require 'ab_test'

module AbTests
  def self.document_capture_session_uuid_discriminator(
    service_provider:,
    session:,
    user:,
    user_session:
  )
    # For users doing hybrid handoff, their document capture session uuid
    # will be stored in session. See Idv::HybridMobile::EntryController
    if session[:document_capture_session_uuid].present?
      return session[:document_capture_session_uuid]
    end

    return unless user_has_idv_session?(user:, user_session:)

    Idv::Session.new(
      current_user: user,
      service_provider:,
      user_session:,
    ).document_capture_session_uuid
  end

  def self.verify_info_step_document_capture_session_uuid_discriminator(
    service_provider:,
    user:,
    user_session:
  )
    return unless user_has_idv_session?(user:, user_session:)

    Idv::Session.new(
      current_user: user,
      service_provider:,
      user_session:,
    ).verify_info_step_document_capture_session_uuid
  end

  def self.user_has_idv_session?(user:, user_session:)
    user && user_session&.key?(:idv)
  end

  # @returns [Hash]
  def self.all
    constants.index_with { |test_name| const_get(test_name) }
  end

  # This "test" will permanently be in place to allow a graceful transition from TrueID being the
  # sole vendor to a multi-vendor configuration.
  DOC_AUTH_VENDOR = AbTest.new(
    experiment_name: 'Doc Auth Vendor',
    should_log: /^idv/i,
    default_bucket: IdentityConfig.store.doc_auth_vendor_default.to_sym,
    buckets: {
      socure: IdentityConfig.store.doc_auth_vendor_switching_enabled ?
        IdentityConfig.store.doc_auth_vendor_socure_percent : 0,
      lexis_nexis: IdentityConfig.store.doc_auth_vendor_switching_enabled ?
        IdentityConfig.store.doc_auth_vendor_lexis_nexis_percent : 0,
    }.compact,
  ) do |service_provider:, session:, user:, user_session:, **|
    user&.uuid
  end.freeze

  # This "test" will permanently be in place to allow a graceful transition from TrueID being the
  # sole vendor to a multi-vendor configuration.
  DOC_AUTH_SELFIE_VENDOR = AbTest.new(
    experiment_name: 'Doc Auth with Selfie Vendor',
    should_log: /^idv/i,
    default_bucket: IdentityConfig.store.doc_auth_selfie_vendor_default.to_sym,
    buckets: {
      socure: IdentityConfig.store.doc_auth_selfie_vendor_switching_enabled ?
          IdentityConfig.store.doc_auth_selfie_vendor_socure_percent : 0,
      lexis_nexis: IdentityConfig.store.doc_auth_selfie_vendor_switching_enabled ?
          IdentityConfig.store.doc_auth_selfie_vendor_lexis_nexis_percent : 0,
    }.compact,
  ) do |service_provider:, session:, user:, user_session:, **|
    user&.uuid
  end.freeze

  ACUANT_SDK = AbTest.new(
    experiment_name: 'Acuant SDK Upgrade',
    should_log: /^idv/i,
    buckets: {
      use_alternate_sdk: IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled ?
        IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_percent :
        0,
    },
  ) do |service_provider:, session:, user:, user_session:, **|
    document_capture_session_uuid_discriminator(service_provider:, session:, user:, user_session:)
  end.freeze

  RECAPTCHA_SIGN_IN = AbTest.new(
    experiment_name: 'reCAPTCHA at Sign-In',
    should_log: [
      'Email and Password Authentication',
      'IdV: doc auth verify proofing results',
      'reCAPTCHA verify result received',
      :idv_enter_password_submitted,
    ].to_set,
    buckets: { sign_in_recaptcha: IdentityConfig.store.sign_in_recaptcha_percent_tested },
  ) do |user:, user_session:, **|
    if user_session&.[](:captcha_validation_performed_at_sign_in) == false
      nil
    elsif user
      user.uuid
    else
      SecureRandom.alphanumeric(8)
    end
  end.freeze

  RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER = AbTest.new(
    experiment_name: 'Recommend Face or Touch Unlock for SMS users',
    should_log: [
      :webauthn_platform_recommended_visited,
      :webauthn_platform_recommended_submitted,
      'Multi-Factor Authentication Setup',
    ].to_set,
    buckets: {
      recommend_for_account_creation:
        IdentityConfig.store.recommend_webauthn_platform_for_sms_ab_test_account_creation_percent,
      recommend_for_authentication:
        IdentityConfig.store.recommend_webauthn_platform_for_sms_ab_test_authentication_percent,
    },
  ).freeze

  ACCOUNT_CREATION_TMX_PROCESSED = AbTest.new(
    experiment_name: 'Account Creation Threat Metrix Processed',
    should_log: [
      :account_creation_tmx_result,
    ].to_set,
    buckets: {
      account_creation_tmx_processed: IdentityConfig.store.account_creation_tmx_processed_percent,
    },
  ) do |user:, user_session:, **|
    user&.uuid
  end.freeze

  ONE_ACCOUNT_USER_VERIFICATION_ENABLED = AbTest.new(
    experiment_name: 'One Account User Verification Enabled',
    should_log: [
      :account_creation_tmx_result,
    ].to_set,
    buckets: {
      one_account_user_verification_enabled_percentage: IdentityConfig.store.one_account_user_verification_enabled_percentage,
    },
    persist: true,
  ) do |user:, user_session:, **|
    user&.uuid
  end.freeze

  SOCURE_IDV_SHADOW_MODE_FOR_NON_DOCV_USERS = AbTest.new(
    experiment_name: 'Socure shadow mode',
    should_log: ['IdV: doc auth verify proofing results'].to_set,
    buckets: {
      socure_shadow_mode_for_non_docv_users: IdentityConfig.store.socure_idplus_shadow_mode_percent,
    },
  ).freeze

  DOC_AUTH_PASSPORT = AbTest.new(
    experiment_name: 'Passport allowed',
    should_log: /^idv/i,
    buckets: {
      passport_allowed: IdentityConfig.store.doc_auth_passports_enabled ?
        IdentityConfig.store.doc_auth_passports_percent : 0,
    },
  ) do |service_provider:, session:, user:, user_session:, **|
    user&.uuid
  end.freeze

  PROOFING_VENDOR = AbTest.new(
    experiment_name: 'Proofing Vendor',
    should_log: /^idv/i,
    default_bucket: IdentityConfig.store.idv_resolution_default_vendor,
    buckets: {
      socure_kyc: IdentityConfig.store.idv_resolution_vendor_switching_enabled ?
          IdentityConfig.store.idv_resolution_vendor_socure_kyc_percent : 0,
      instant_verify: IdentityConfig.store.idv_resolution_vendor_switching_enabled ?
          IdentityConfig.store.idv_resolution_vendor_instant_verify_percent : 0,
    },
  ) do |service_provider:, session:, user:, user_session:, **|
    verify_info_step_document_capture_session_uuid_discriminator(
      service_provider:, user:, user_session:,
    )
  end.freeze

  # This "test" will permanently be in place to allow a multi-vendor configuration.
  DOC_AUTH_PASSPORT_VENDOR = AbTest.new(
    experiment_name: 'Doc Auth Passport Vendor',
    should_log: /^idv/i,
    default_bucket: IdentityConfig.store.doc_auth_passport_vendor_default.to_sym,
    buckets: {
      socure: IdentityConfig.store.doc_auth_passport_vendor_switching_enabled ?
          IdentityConfig.store.doc_auth_passport_vendor_socure_percent : 0,
      lexis_nexis: IdentityConfig.store.doc_auth_passport_vendor_switching_enabled ?
          IdentityConfig.store.doc_auth_passport_vendor_lexis_nexis_percent : 0,
    }.compact,
  ) do |service_provider:, session:, user:, user_session:, **|
    user&.uuid
  end.freeze
end
