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
    buckets: {
      socure: IdentityConfig.store.doc_auth_vendor_switching_enabled ?
        IdentityConfig.store.doc_auth_vendor_socure_percent :
        0,
    }.compact,
  ) do |service_provider:, session:, user:, user_session:, **|
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
