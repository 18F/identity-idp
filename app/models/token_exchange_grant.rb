# frozen_string_literal: true

# A user's grant allowing a broker service provider to exchange its token for a
# token bound to a target service provider. One row per (user, broker, target);
# the ALL_TARGETS sentinel row expresses a grant covering every target.
#
# Timestamps are kept per target so the user's decision about each application
# is independently recorded, audited, and expirable.
class TokenExchangeGrant < ApplicationRecord
  ALL_TARGETS = '*'
  GRANT_DURATION = 12.months.freeze

  belongs_to :user

  validates :broker_issuer, :target_issuer, :granted_at, :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.zone.now) }
  scope :for_broker, ->(broker_issuer) { where(broker_issuer: broker_issuer) }

  # Whether the user has an active grant letting +broker_issuer+ mint for
  # +target_issuer+. Authorized by an exact per-target row, or by an all-targets
  # row that includes future targets. An all-targets row WITHOUT includes_future
  # only covers the targets snapshotted as individual rows at consent time, so a
  # target the broker adds later is never silently authorized.
  def self.authorizes?(user:, broker_issuer:, target_issuer:)
    grants = active.where(user: user, broker_issuer: broker_issuer)
    return true if grants.exists?(target_issuer: target_issuer)

    grants.exists?(target_issuer: ALL_TARGETS, includes_future: true)
  end

  # Records the user's consent decision, replacing any prior grants for this
  # broker so a changed decision never leaves stale per-target rows behind.
  #
  # @param choice [:all, :all_and_future, :specific]
  # @param targets [Array<String>] issuers the broker may currently reach (for
  #   :all, every one is snapshotted); for :specific, the issuers chosen.
  def self.record!(user:, broker_issuer:, choice:, targets:, now: Time.zone.now)
    transaction do
      where(user: user, broker_issuer: broker_issuer).delete_all

      rows = case choice.to_s
      when 'all_and_future'
        [[ALL_TARGETS, true], *targets.map { |t| [t, false] }]
      when 'all'
        [[ALL_TARGETS, false], *targets.map { |t| [t, false] }]
      when 'specific'
        targets.map { |t| [t, false] }
      else
        []
      end

      rows.uniq.map do |target_issuer, includes_future|
        create!(
          user: user,
          broker_issuer: broker_issuer,
          target_issuer: target_issuer,
          includes_future: includes_future,
          granted_at: now,
          expires_at: now + GRANT_DURATION,
        )
      end
    end
  end

  def self.revoke_all!(user:, broker_issuer:, now: Time.zone.now)
    active.where(user: user, broker_issuer: broker_issuer).find_each do |grant|
      grant.update!(revoked_at: now)
    end
  end

  def all_targets?
    target_issuer == ALL_TARGETS
  end
end
