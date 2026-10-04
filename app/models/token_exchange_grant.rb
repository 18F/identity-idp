# frozen_string_literal: true

# A user's grant allowing a broker service provider to exchange its token for a
# token bound to ONE target service provider. Strictly one row per
# (user, broker, target): "allow all" is expressed by materializing a row for
# every application it covers, never by a wildcard, so each application the user
# authorized has its own independently recorded, revocable, expirable timestamp
# and later per-application toggles never fight an overriding "all" state.
#
# Superseded grants are revoked, not deleted, so the audit trail of what the
# user authorized -- and when they changed it -- is preserved.
class TokenExchangeGrant < ApplicationRecord
  GRANT_DURATION = 12.months.freeze

  class InvalidGrant < StandardError; end

  belongs_to :user

  validates :broker_issuer, :target_issuer, :granted_at, :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.zone.now) }
  scope :for_broker, ->(broker_issuer) { where(broker_issuer: broker_issuer) }

  # Whether the user holds an active grant letting +broker_issuer+ mint for
  # +target_issuer+. Only an exact per-application row authorizes; there is no
  # wildcard.
  def self.authorizes?(user:, broker_issuer:, target_issuer:)
    return false if target_issuer.blank?

    active.exists?(user: user, broker_issuer: broker_issuer, target_issuer: target_issuer)
  end

  # Grants the given targets, superseding any prior grants for this broker that
  # are NOT in the new set (so a changed decision never leaves stale
  # authorizations behind). Targets already granted keep their original
  # granted_at; new ones are stamped +granted_at+ (defaults to now).
  #
  # @param targets [Array<String>] target issuers to authorize
  # @param granted_at [Time] timestamp to record for newly granted targets
  # @return [Array<TokenExchangeGrant>] the active grants after the change
  def self.grant!(user:, broker_issuer:, targets:, granted_at: Time.zone.now)
    targets = Array(targets).map(&:to_s).reject(&:blank?).uniq

    transaction do
      user.lock!
      active.where(user: user, broker_issuer: broker_issuer)
        .where.not(target_issuer: targets)
        .find_each { |grant| grant.update!(revoked_at: Time.zone.now) }

      targets.map do |target_issuer|
        grant = find_or_initialize_by(
          user: user, broker_issuer: broker_issuer, target_issuer: target_issuer,
        )
        if grant.new_record? || grant.revoked_at.present? || grant.expires_at <= Time.zone.now
          grant.assign_attributes(
            granted_at: granted_at,
            expires_at: granted_at + GRANT_DURATION,
            revoked_at: nil,
          )
        end
        grant.save!
        grant
      end
    end
  end

  # Grants a single additional target without disturbing other grants. Used by
  # the account-page toggle and by auto-enrollment.
  #
  # @param unless_revoked [Boolean] when true, a target the user explicitly
  #   revoked is left alone (auto-enrollment must never override a deliberate
  #   per-application "off"); when false (an explicit user action) a revoked
  #   row is re-granted.
  def self.grant_one!(user:, broker_issuer:, target_issuer:, granted_at: Time.zone.now,
                      unless_revoked: false)
    transaction do
      user.lock!
      grant = find_or_initialize_by(
        user: user, broker_issuer: broker_issuer, target_issuer: target_issuer,
      )
      active_now = grant.persisted? && grant.revoked_at.nil? && grant.expires_at > Time.zone.now
      return grant if active_now
      return grant if unless_revoked && grant.persisted? && grant.revoked_at.present?

      grant.update!(
        granted_at: granted_at,
        expires_at: granted_at + GRANT_DURATION,
        revoked_at: nil,
      )
      grant
    end
  end

  def self.revoke!(user:, broker_issuer:, target_issuer:, now: Time.zone.now)
    active.where(user: user, broker_issuer: broker_issuer, target_issuer: target_issuer)
      .find_each { |grant| grant.update!(revoked_at: now) }
  end

  def self.revoke_all!(user:, broker_issuer:, now: Time.zone.now)
    active.where(user: user, broker_issuer: broker_issuer).find_each do |grant|
      grant.update!(revoked_at: now)
    end
  end
end
