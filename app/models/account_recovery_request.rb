# frozen_string_literal: true

class AccountRecoveryRequest < ApplicationRecord
  belongs_to :user

  REQUESTED = 'requested'
  WAITING = 'waiting'
  GRANTED = 'granted'
  LINK_VERIFIED = 'link_verified'
  PASSWORD_VERIFIED = 'password_verified'
  REPLACEMENT_MFA_PENDING = 'replacement_mfa_pending'
  COMPLETED = 'completed'
  CANCELLED = 'cancelled'
  EXPIRED = 'expired'

  ACTIVE_STATES = [
    REQUESTED,
    WAITING,
    GRANTED,
    LINK_VERIFIED,
    PASSWORD_VERIFIED,
    REPLACEMENT_MFA_PENDING,
  ].freeze

  TERMINAL_STATES = [COMPLETED, CANCELLED, EXPIRED].freeze

  STATES = (ACTIVE_STATES + TERMINAL_STATES).freeze

  # Bounded cancellation and failure reasons, safe for analytics.
  CANCEL_REASON_USER_CANCELLED = 'user_cancelled'
  CANCEL_REASON_MFA_USED = 'mfa_used'
  CANCEL_REASON_INELIGIBLE = 'ineligible'
  FAILURE_REASON_TOKEN_NOT_REDEEMED = 'token_not_redeemed'

  TRANSITIONS = {
    REQUESTED => [WAITING, CANCELLED, EXPIRED],
    WAITING => [GRANTED, CANCELLED, EXPIRED],
    GRANTED => [LINK_VERIFIED, CANCELLED, EXPIRED],
    LINK_VERIFIED => [PASSWORD_VERIFIED, CANCELLED, EXPIRED],
    PASSWORD_VERIFIED => [REPLACEMENT_MFA_PENDING, CANCELLED, EXPIRED],
    REPLACEMENT_MFA_PENDING => [COMPLETED, CANCELLED, EXPIRED],
  }.freeze

  STATE_TIMESTAMPS = {
    REQUESTED => :requested_at,
    GRANTED => :granted_at,
    LINK_VERIFIED => :link_verified_at,
    PASSWORD_VERIFIED => :password_verified_at,
    COMPLETED => :completed_at,
    CANCELLED => :cancelled_at,
    EXPIRED => :expired_at,
  }.freeze

  validates :state, inclusion: { in: STATES }

  scope :active, -> {
    where(
      completed_at: nil,
      cancelled_at: nil,
      expired_at: nil,
    )
  }

  def self.active_for_user(user)
    active.where(user: user).order(requested_at: :asc).first
  end

  # @param fingerprint [String] keyed fingerprint of a raw token
  def self.active_for_token_fingerprint(fingerprint)
    return nil if fingerprint.blank?

    active.find_by(token_fingerprint: fingerprint)
  end

  def active?
    ACTIVE_STATES.include?(state)
  end

  def replacement_mfa_pending?
    active? && state == REPLACEMENT_MFA_PENDING
  end

  def terminal?
    TERMINAL_STATES.include?(state)
  end

  def can_transition_to?(next_state)
    TRANSITIONS.fetch(state, []).include?(next_state)
  end

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

  def expire!(reason: nil)
    transition_to!(EXPIRED, failure_reason: reason, **cleared_token_attributes)
  end

  def token_valid?
    token_fingerprint.present? && !token_expired?
  end

  def token_expired?
    token_expires_at.blank? || token_expires_at <= Time.zone.now
  end

  # User cancellation and automatic cancellation on MFA use stop at link
  # verification. Token expiration still applies until password verification.
  def awaiting_link_redemption?
    [REQUESTED, WAITING, GRANTED].include?(state)
  end

  private

  def cleared_token_attributes
    {
      token_fingerprint: nil,
      token_expires_at: nil,
    }
  end
end
