# frozen_string_literal: true

module AccountRecovery
  # Bounded, non-PII attributes describing the user requesting recovery, so
  # recovery outcomes can be segmented by account and MFA method profile.
  class RequestAnalyticsAttributes
    # @param user [User]
    # @param now [ActiveSupport::TimeWithZone]
    def initialize(user:, now: Time.zone.now)
      @user = user
      @now = now
    end

    # @return [Hash]
    def call
      {
        account_age_in_days: account_age_in_days,
        days_since_last_full_sign_in: days_since_last_full_sign_in,
        enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
        mfa_method_ages_in_days: mfa_method_ages_in_days,
        mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
        pii_like_keypaths: [[:mfa_method_counts, :phone], [:mfa_method_ages_in_days, :phone]],
      }
    end

    private

    attr_reader :user, :now

    def mfa_context
      @mfa_context ||= MfaContext.new(user)
    end

    def account_age_in_days
      days_since(user.confirmed_at)
    end

    # Age of the most recently added configuration of each enabled method type.
    def mfa_method_ages_in_days
      mfa_context.two_factor_configurations
        .select(&:mfa_enabled?)
        .group_by(&:friendly_name)
        .transform_values { |configurations| days_since(configurations.map(&:created_at).max) }
    end

    def days_since_last_full_sign_in
      last_sign_in_at = user.events
        .where(event_type: :sign_in_after_2fa)
        .order(created_at: :desc)
        .pick(:created_at)

      days_since(last_sign_in_at)
    end

    def days_since(time)
      return if time.blank?

      (now - time).seconds.in_days.floor
    end
  end
end
