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

    # Otherwise, try to get the user's current Idv::Session and read
    # the generated document_capture_session UUID from there
    return if !(user && user_session)

    # Avoid creating a pointless :idv entry in user_session if the
    # user has not already started IdV
    return unless user_session.key?(:idv)

    Idv::Session.new(
      current_user: user,
      service_provider:,
      user_session:,
    ).document_capture_session_uuid
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

  SOCURE_IDV_SHADOW_MODE_FOR_NON_DOCV_USERS = AbTest.new(
    experiment_name: 'Socure shadow mode',
    should_log: ['IdV: doc auth verify proofing results'].to_set,
    buckets: {
      socure_shadow_mode_for_non_docv_users: IdentityConfig.store.socure_idplus_shadow_mode_percent,
    },
  ).freeze

  DESKTOP_FT_UNLOCK_SETUP = AbTest.new(
    experiment_name: 'Desktop F/T unlock setup',
    should_log: [
      'User Registration: 2FA Setup visited',
      'WebAuthn Setup Visited',
      :webauthn_setup_submitted,
      'Multi-Factor Authentication Setup',
    ].to_set,
    buckets: { desktop_ft_unlock_option_shown:
        IdentityConfig.store.desktop_ft_unlock_setup_option_percent_tested },
  ).freeze

  DOC_AUTH_PASSPORT = AbTest.new(
    experiment_name: 'Passport allowed',
    should_log: /^idv/i,
    buckets: {
      passport_enabled: IdentityConfig.store.doc_auth_passports_enabled ?
        IdentityConfig.store.doc_auth_passports_percent_enabled : 0,
    },
  ) do |service_provider:, session:, user:, user_session:, **|
    user&.uuid
  end.freeze
end
