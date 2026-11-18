# frozen_string_literal: true

module AccountRecovery
  # Frees a suspended credential so the user can re-enroll the same thing during
  # replacement MFA setup.
  #
  # Suspension keeps the old rows in place, which collides with the uniqueness
  # rules on setup (a global unique index on PIV/CAC +x509_dn_uuid+, per-user
  # unique indexes on configuration names) and would otherwise stop a user from
  # re-adding the very card or name they just lost access to. These rows are
  # deleted when recovery completes anyway, so releasing one early changes only
  # the timing.
  #
  # Callers should use +#releasable?+ while validating and +#call+ only when
  # about to enroll, so a failed submission does not destroy the old credential.
  #
  # Nothing else is touched: a row belonging to another user, or one that is not
  # suspended by this user's in-flight recovery, is left alone so the normal
  # uniqueness errors still apply.
  class ReleaseSuspendedCredential
    # @return [ApplicationRecord, nil] the colliding configuration under test
    attr_reader :configuration

    # @param user [User] user attempting to enroll a replacement
    # @param configuration [ApplicationRecord, nil] colliding MFA configuration
    def initialize(user:, configuration:)
      @user = user
      @configuration = configuration
    end

    # @return [Boolean] whether the colliding configuration may be released
    def releasable?
      return false if user.blank? || configuration.blank?
      return false if configuration.user_id != user.id
      return false unless configuration.respond_to?(:suspended_for_account_recovery?)
      return false unless configuration.suspended_for_account_recovery?

      suspended_by_active_recovery?
    end

    # @return [Boolean] whether the colliding configuration was released
    def call
      return false unless releasable?

      configuration.destroy!
      true
    end

    private

    attr_reader :user

    # Only the request that is currently awaiting replacement MFA may release
    # its own suspended credentials. A terminal request's rows are not in play,
    # and a request before password verification has not suspended anything.
    def suspended_by_active_recovery?
      recovery_request = AccountRecoveryRequest.active_for_user(user)

      recovery_request.present? &&
        recovery_request.id == configuration.account_recovery_request_id &&
        recovery_request.replacement_mfa_pending?
    end
  end
end
