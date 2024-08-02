# frozen_string_literal: true

require 'ab_test'

module AbTests
  # Helper method that enables using an Idv::Session to calculate a discriminator value.
  # If no Idv::Session is available, `nil` is used as the discriminator value.
  # @yieldparam [Idv::Session,nil] The current Idv::Session that can be used to determine
  #                                 a discriminator value
  # @returns [Proc]
  def self.idv_session_discriminator
    ->(request:, service_provider:, user:, user_session:) do
      # If we don't have a logged-in user, we can't use an Idv::Session-based discriminator.
      return nil if user.blank? || user.is_a?(AnonymousUser)

      # If we don't have a user session, we _can't_ have an Idv::Session
      return nil if user_session.nil?

      yield Idv::Session.new(
        current_user: user,
        service_provider:,
        user_session:,
      )
    end
  end

  DOC_AUTH_VENDOR = AbTest.new(
    experiment_name: 'Doc Auth Vendor',
    buckets: {
      alternate_vendor: IdentityConfig.store.doc_auth_vendor_randomize ?
        IdentityConfig.store.doc_auth_vendor_randomize_percent :
        0,
    }.compact,
  ) do |request:, service_provider:, user:, user_session:|
    idv_session_discriminator(request:, service_provider:, user:, user_session:)
  end.freeze

  ACUANT_SDK = AbTest.new(
    experiment_name: 'Acuant SDK Upgrade',
    buckets: {
      use_alternate_sdk: IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled ?
        IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_percent :
        0,
    },
  ) do |request:, service_provider:, user:, user_session:|
    idv_session_discriminator(request:, service_provider:, user:, user_session:)
  end.freeze
end
