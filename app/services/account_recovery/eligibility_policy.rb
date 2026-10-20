# frozen_string_literal: true

module AccountRecovery
  class EligibilityPolicy
    # @param user [User, nil]
    def initialize(user:)
      @user = user
    end

    def eligible?
      return false if user.blank? || user.is_a?(AnonymousUser)
      return false unless IdentityConfig.store.account_recovery_v2_enabled
      return false unless user.fully_registered?
      return false unless MfaPolicy.new(user).two_factor_enabled?
      return false if user.active_profile? || user.pending_profile?
      return false if user.password_reset_profile.present?
      return false if user.suspended? || user.fraud_review_pending? || user.fraud_rejection?
      return false unless user.confirmed_email_addresses.any?

      !existing_request_pending?
    end

    private

    attr_reader :user

    # A user may not hold active requests in both workflows, so an in-flight
    # request in either one blocks a new account-preserving request.
    def existing_request_pending?
      AccountRecoveryRequest.active.exists?(user: user) ||
        DestructiveAccountReset::PendingRequestForUser.new(user).get_account_reset_request.present?
    end
  end
end
