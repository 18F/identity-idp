# frozen_string_literal: true

# One refresh token a token exchange actor can trade for a new subject token. Tokens rotate:
# each use marks the row used and adds a new row to the same family. A family belongs to one
# sign-in and never outlives `family_expires_at`, which counts from the person's authentication
# and is never extended. Presenting a used token again revokes the whole family (RFC 9700
# §4.14.2), since only a copy of the token could explain a second use.
class TokenExchangeRefreshToken < ApplicationRecord
  REVOCATION_REASONS = %w[
    reuse_detected
    revoked_by_client
    service_provider_disconnected
    consent_revoked
    security_event
  ].freeze

  belongs_to :user

  validates :token_digest, :family_id, :actor_issuer, :identity_uuid, :dpop_jkt,
            :authenticated_at, :family_expires_at, :expires_at, presence: true
  validates :revocation_reason, inclusion: { in: REVOCATION_REASONS }, allow_nil: true

  scope :unrevoked, -> { where(revoked_at: nil) }
  scope :family_expired, ->(now = Time.zone.now) { where(family_expires_at: ...now) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.for_token(token)
    return if token.blank?

    find_by(token_digest: digest(token))
  end

  # Revokes every refresh token in the given families that isn't revoked already, so the actor
  # can get no further subject tokens from them. Subject tokens already issued run out their own
  # short lifetime.
  # @return [Integer] the number of tokens revoked
  def self.revoke_families!(family_ids, reason:, now: Time.zone.now)
    if REVOCATION_REASONS.exclude?(reason)
      raise ArgumentError, "unknown revocation reason: #{reason}"
    end

    # rubocop:disable Rails/SkipsModelValidations
    unrevoked
      .where(family_id: family_ids)
      .update_all(revoked_at: now, revocation_reason: reason, updated_at: now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def expired?(now: Time.zone.now)
    expires_at <= now || family_expires_at <= now
  end

  def used?
    used_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  def revoke_family!(reason:, now: Time.zone.now)
    self.class.revoke_families!([family_id], reason:, now:)
  end
end
