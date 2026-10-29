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

    private

    attr_reader :user
  end
end
