# frozen_string_literal: true

module TwoFactorAuthentication
  # Checks if a user has a personal key as a 2FA method
  # (legacy 2FA, independent of having one for a profile)
  class PersonalKeyPolicy
    def initialize(user)
      @user = user
    end

    def configured?
      user&.has_recovery_code?
    end

    def enabled?
      configured? && user.profiles.none?
    end

    # Phase 1 of personal key MFA deprecation applies to users who use a personal
    # key as an MFA method (enabled?) AND have another, non-personal-key MFA
    # method (MfaPolicy#two_factor_enabled?). Identity-verified users are excluded
    # because enabled? is false for them (they have profiles) — they use their
    # personal key for account recovery/IDV. Legacy users whose ONLY credential is
    # a personal key are excluded too, so the deprecation never leaves an account
    # without a usable credential.
    def mfa_deprecated?
      FeatureManagement.personal_key_mfa_deprecation_phase_1_enabled? &&
        enabled? &&
        MfaPolicy.new(user).two_factor_enabled?
    end

    # A legacy account whose ONLY credential beyond the password is a personal key:
    # the key is its second factor, so the password alone must not authenticate it,
    # and the key must be verified before any other method may be added. Identity-
    # verified users are excluded because enabled? is false for them (they have
    # profiles), and users with another MFA method are excluded because that method
    # is used to authenticate instead (MfaPolicy#two_factor_enabled?).
    def only_credential?
      enabled? && !MfaPolicy.new(user).two_factor_enabled?
    end

    # Phase 1 of personal key MFA deprecation: a user whose only credential is a
    # personal key is told to add a replacement method right after verifying the
    # key, and the key is retired once the replacement is confirmed.
    def mfa_required?
      FeatureManagement.personal_key_mfa_deprecation_phase_1_enabled? && only_credential?
    end

    private

    attr_reader :user
  end
end
