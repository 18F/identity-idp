# frozen_string_literal: true

# Per-(user, broker) settings for token exchange that are not tied to a single
# target application. Today that is auto-enrollment: when enabled, any new
# application the user connects to their account that has opted in to the broker
# is granted automatically, with its grant stamped at the time auto-enrollment
# was ORIGINALLY granted (the user's consent moment), not at first use.
class TokenExchangeBrokerSetting < ApplicationRecord
  belongs_to :user

  validates :broker_issuer, presence: true

  def self.for(user:, broker_issuer:)
    find_or_initialize_by(user: user, broker_issuer: broker_issuer)
  end

  def auto_enroll_enabled?
    auto_enroll_granted_at.present? && auto_enroll_revoked_at.nil? &&
      auto_enroll_granted_at > TokenExchangeGrant::GRANT_DURATION.ago
  end

  # Re-enabling keeps the ORIGINAL consent time (if still within the grant
  # duration) so later auto-enrolled applications are stamped with the user's
  # first consent, not the toggle time. Once the original consent has aged out,
  # re-enabling is a fresh consent and is stamped now.
  def enable_auto_enroll!(now: Time.zone.now)
    original = auto_enroll_granted_at
    keep_original = original.present? && original > now - TokenExchangeGrant::GRANT_DURATION
    update!(
      auto_enroll_granted_at: keep_original ? original : now,
      auto_enroll_revoked_at: nil,
    )
  end

  def disable_auto_enroll!(now: Time.zone.now)
    update!(auto_enroll_revoked_at: now) if auto_enroll_enabled?
  end

  # Grants +target_service_provider+ under this setting when auto-enrollment is
  # on, the broker is still connected to the user's account and still an
  # allow-listed broker, and the target has opted in to the broker. Stamped at
  # auto_enroll_granted_at (the original consent), never at first use. A target
  # the user explicitly turned off is left off: "new agencies" never overrides a
  # deliberate per-application revocation.
  def auto_enroll!(target_service_provider)
    return unless auto_enroll_enabled?
    return if target_service_provider.blank? || target_service_provider.issuer == broker_issuer
    return unless target_service_provider.allows_token_exchange_broker?(broker_issuer)
    return unless broker_still_connected?

    TokenExchangeGrant.grant_one!(
      user: user,
      broker_issuer: broker_issuer,
      target_issuer: target_service_provider.issuer,
      granted_at: auto_enroll_granted_at,
      unless_revoked: true,
    )
  end

  private

  def broker_still_connected?
    broker = ServiceProvider.find_by(issuer: broker_issuer)
    broker&.token_exchange_broker_allowed? &&
      user.connected_apps.exists?(service_provider: broker_issuer)
  end
end
