# frozen_string_literal: true

require 'ab_test'

module AbTests
  def self.document_capture_session_uuid_discriminator(
    service_provider:,
    session:,
    user:,
    user_session:
  )
    # If we don't have a user, there _may_ be a document capture session UUID
    # sitting in session if the user is currently doing hybrid handoff.
    return session[:document_capture_session_uuid] if !user

    # Otherwise, try to get the user's current Idv::Session and read
    # the generated document_capture_session UUID from there
    return if !user_session

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

  DOC_AUTH_VENDOR = AbTest.new(
    experiment_name: 'Doc Auth Vendor',
    should_log: /^idv/i,
    buckets: {
      alternate_vendor: IdentityConfig.store.doc_auth_vendor_randomize ?
        IdentityConfig.store.doc_auth_vendor_randomize_percent :
        0,
    }.compact,
  ) do |session:, user:, user_session:, **|
    document_capture_session_uuid_discriminator(service_provider:, session:, user:, user_session:)
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
end
