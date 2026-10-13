# frozen_string_literal: true

# Persistence for the account-preserving MFA recovery workflow described in
# docs/adr/0001-account-preserving-mfa-recovery.md.
#
# This record is intentionally separate from AccountResetRequest. The legacy
# destructive account reset keeps its own record and lifecycle, and a request
# never moves between the two workflows once created.
class AccountRecoveryRequest < ApplicationRecord
  belongs_to :user
  # rubocop:disable Rails/InverseOf
  belongs_to :requesting_service_provider,
             class_name: 'ServiceProvider',
             foreign_key: 'requesting_issuer',
             primary_key: 'issuer',
             optional: true
  # rubocop:enable Rails/InverseOf

  FLOW_VARIANT_ACCOUNT_PRESERVING = 'account_preserving'

  REQUESTED = 'requested'
  WAITING = 'waiting'
  GRANTED = 'granted'
  LINK_VERIFIED = 'link_verified'
  PASSWORD_VERIFIED = 'password_verified'
  REPLACEMENT_MFA_PENDING = 'replacement_mfa_pending'
  COMPLETED = 'completed'
  CANCELLED = 'cancelled'
  EXPIRED = 'expired'
  SUPERSEDED = 'superseded'

  ACTIVE_STATES = [
    REQUESTED,
    WAITING,
    GRANTED,
    LINK_VERIFIED,
    PASSWORD_VERIFIED,
    REPLACEMENT_MFA_PENDING,
  ].freeze

  TERMINAL_STATES = [COMPLETED, CANCELLED, EXPIRED, SUPERSEDED].freeze

  STATES = (ACTIVE_STATES + TERMINAL_STATES).freeze

  # Allowed state transitions, per the ADR state machine. Terminal states have
  # no outbound transitions and are deliberately absent from this table.
  TRANSITIONS = {
    REQUESTED => [WAITING, CANCELLED, EXPIRED, SUPERSEDED],
    WAITING => [GRANTED, CANCELLED, EXPIRED, SUPERSEDED],
    GRANTED => [LINK_VERIFIED, CANCELLED, EXPIRED, SUPERSEDED],
    LINK_VERIFIED => [PASSWORD_VERIFIED, CANCELLED, EXPIRED, SUPERSEDED],
    PASSWORD_VERIFIED => [REPLACEMENT_MFA_PENDING, CANCELLED, EXPIRED, SUPERSEDED],
    REPLACEMENT_MFA_PENDING => [COMPLETED, CANCELLED, EXPIRED, SUPERSEDED],
  }.freeze

  # Column that records when each state was entered.
  STATE_TIMESTAMPS = {
    REQUESTED => :requested_at,
    GRANTED => :granted_at,
    LINK_VERIFIED => :link_verified_at,
    PASSWORD_VERIFIED => :password_verified_at,
    COMPLETED => :completed_at,
    CANCELLED => :cancelled_at,
    EXPIRED => :expired_at,
    SUPERSEDED => :superseded_at,
  }.freeze

  validates :state, inclusion: { in: STATES }
  validates :flow_variant, presence: true

  # Matches the predicate on index_account_recovery_requests_on_active_user_id,
  # so the scope and the database's one-active-request-per-user guarantee cannot
  # drift apart. Every terminal transition stamps exactly one of these columns.
  scope :active, -> {
    where(
      completed_at: nil,
      cancelled_at: nil,
      expired_at: nil,
      superseded_at: nil,
    )
  }

  def self.active_for_user(user)
    active.where(user: user).order(requested_at: :asc).first
  end

  def active?
    ACTIVE_STATES.include?(state)
  end

  def terminal?
    TERMINAL_STATES.include?(state)
  end

  def can_transition_to?(next_state)
    TRANSITIONS.fetch(state, []).include?(next_state)
  end

  # Atomically moves the request to the next state. Returns false without
  # mutating anything when the transition is not allowed from the current
  # state, so callers fail closed rather than silently skipping a step.
  #
  # @param next_state [String] one of STATES
  # @param attributes [Hash] additional columns to write in the same update
  # @return [Boolean] whether the transition was applied
  def transition_to!(next_state, **attributes)
    raise ArgumentError, "unknown state: #{next_state}" unless STATES.include?(next_state)

    transitioned = false

    with_lock do
      if can_transition_to?(next_state)
        timestamp_column = STATE_TIMESTAMPS[next_state]
        changes = attributes.merge(state: next_state)
        changes[timestamp_column] ||= Time.zone.now if timestamp_column

        update!(**changes)
        transitioned = true
      end
    end

    transitioned
  end

  def wait!
    transition_to!(WAITING)
  end

  def cancel!(reason:)
    transition_to!(CANCELLED, cancel_reason: reason, **cleared_token_attributes)
  end

  def supersede!
    transition_to!(SUPERSEDED, **cleared_token_attributes)
  end

  def expire!(reason: nil)
    transition_to!(EXPIRED, failure_reason: reason, **cleared_token_attributes)
  end

  def token_valid?
    token_fingerprint.present? && !token_expired?
  end

  def token_expired?
    token_expires_at.blank? || token_expires_at <= Time.zone.now
  end

  private

  def cleared_token_attributes
    { token_fingerprint: nil, token_expires_at: nil }
  end
end
