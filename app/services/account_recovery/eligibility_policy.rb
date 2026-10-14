# frozen_string_literal: true

module AccountRecovery
  # Decides whether a user may enter the account-preserving MFA recovery
  # workflow, per docs/adr/0001-account-preserving-mfa-recovery.md.
  #
  # Ineligible users fall back to the legacy destructive account reset.
  # Unexpected errors propagate to the application's error handling. The result is
  # re-evaluated on the server at every transition. A decision made while
  # rendering a page is never sufficient authorization for a later transition.
  class EligibilityPolicy
    # Bounded, non-PII reasons safe for analytics.
    ELIGIBLE = :eligible
    FEATURE_DISABLED = :feature_disabled
    NO_MFA_CONFIGURED = :no_mfa_configured
    NOT_FULLY_REGISTERED = :not_fully_registered
    IDENTITY_VERIFIED = :identity_verified
    PENDING_PROFILE = :pending_profile
    PASSWORD_RESET_PROFILE = :password_reset_profile
    ACCOUNT_SUSPENDED = :account_suspended
    FRAUD_RESTRICTED = :fraud_restricted
    NO_CONFIRMED_EMAIL = :no_confirmed_email
    EXISTING_REQUEST_PENDING = :existing_request_pending
    NO_USER = :no_user

    Result = Struct.new(:eligible, :reason, keyword_init: true) do
      alias_method :eligible?, :eligible
    end

    # @param user [User, nil]
    def initialize(user:)
      @user = user
      @account_recovery_v2_enabled = IdentityConfig.store.account_recovery_v2_enabled
    end

    # @return [Result]
    def call
      reason = ineligible_reason
      Result.new(eligible: reason.nil?, reason: reason || ELIGIBLE)
    end

    def eligible?
      call.eligible?
    end

    private

    attr_reader :user, :account_recovery_v2_enabled

    # Returns the first failing check, or nil when the user is eligible.
    # Ordered cheapest-and-most-decisive first so analytics reasons are stable.
    def ineligible_reason
      return NO_USER if user.blank? || user.is_a?(AnonymousUser)
      return FEATURE_DISABLED unless account_recovery_v2_enabled
      return NO_MFA_CONFIGURED unless MfaPolicy.new(user).two_factor_enabled?
      return IDENTITY_VERIFIED if user.active_profile?
      return PENDING_PROFILE if user.pending_profile?
      return PASSWORD_RESET_PROFILE if user.password_reset_profile.present?
      return ACCOUNT_SUSPENDED if user.suspended?
      return FRAUD_RESTRICTED if user.fraud_review_pending? || user.fraud_rejection?
      return NO_CONFIRMED_EMAIL unless user.confirmed_email_addresses.any?
      return EXISTING_REQUEST_PENDING if existing_request_pending?

      nil
    end

    # A user may not hold active requests in both workflows, so an in-flight
    # request in either one blocks a new account-preserving request.
    def existing_request_pending?
      AccountRecoveryRequest.active.exists?(user: user) ||
        AccountReset::PendingRequestForUser.new(user).get_account_reset_request.present?
    end
  end
end
