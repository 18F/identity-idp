# frozen_string_literal: true

# A user's grant allowing a broker service provider to exchange its token for a
# token bound to a target service provider. One row per (user, broker, target);
# the ALL_TARGETS sentinel row expresses a grant covering every target.
#
# Timestamps are kept per target so the user's decision about each application
# is independently recorded, audited, and expirable. Superseded grants are
# revoked, not deleted, so the audit trail of what the user authorized -- and
# when they changed it -- is preserved.
class TokenExchangeGrant < ApplicationRecord
  ALL_TARGETS = '*'
  GRANT_DURATION = 12.months.freeze
  CHOICES = %w[all all_and_future specific].freeze

  class InvalidGrant < StandardError; end

  belongs_to :user

  validates :broker_issuer, :target_issuer, :granted_at, :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.zone.now) }
  scope :for_broker, ->(broker_issuer) { where(broker_issuer: broker_issuer) }

  # Whether the user has an active grant letting +broker_issuer+ mint for
  # +target_issuer+. Authorized by an exact per-target row, or by an all-targets
  # row that includes future targets. An all-targets row WITHOUT includes_future
  # only covers the targets snapshotted as individual rows at consent time, so a
  # target the broker adds later is never silently authorized. The sentinel is
  # never itself an authorizable target.
  def self.authorizes?(user:, broker_issuer:, target_issuer:)
    return false if target_issuer.blank? || target_issuer == ALL_TARGETS

    grants = active.where(user: user, broker_issuer: broker_issuer)
    return true if grants.exists?(target_issuer: target_issuer)

    grants.exists?(target_issuer: ALL_TARGETS, includes_future: true)
  end

  # Records the user's consent decision, superseding any prior grants for this
  # broker so a changed decision never leaves stale per-target authorizations
  # behind (prior rows are revoked, preserving the audit trail).
  #
  # @param choice [String, Symbol] one of CHOICES
  # @param targets [Array<String>] issuers the broker may currently reach (for
  #   an all-targets choice, every one is snapshotted); for :specific, the
  #   issuers the user chose.
  # @raise [InvalidGrant] for an unknown choice, a grant that would authorize
  #   nothing (no reachable targets), or the sentinel supplied as a target.
  def self.record!(user:, broker_issuer:, choice:, targets:, now: Time.zone.now)
    choice = choice.to_s
    targets = Array(targets).map(&:to_s).uniq
    raise InvalidGrant, 'unknown choice' unless CHOICES.include?(choice)
    raise InvalidGrant, 'sentinel is not a target' if targets.include?(ALL_TARGETS)
    raise InvalidGrant, 'grant covers no targets' if targets.empty? && choice != 'all_and_future'

    rows =
      case choice
      when 'all_and_future' then [[ALL_TARGETS, true], *targets.map { |t| [t, false] }]
      when 'all' then [[ALL_TARGETS, false], *targets.map { |t| [t, false] }]
      else targets.map { |t| [t, false] }
      end

    transaction do
      user.lock!
      active.where(user: user, broker_issuer: broker_issuer).find_each do |grant|
        grant.update!(revoked_at: now)
      end

      rows.map do |target_issuer, includes_future|
        grant = find_or_initialize_by(
          user: user, broker_issuer: broker_issuer, target_issuer: target_issuer,
        )
        grant.update!(
          includes_future: includes_future,
          granted_at: now,
          expires_at: now + GRANT_DURATION,
          revoked_at: nil,
        )
        grant
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
