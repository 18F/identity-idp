# frozen_string_literal: true

# The issuance record of one delegated-access exchange: an opaque access token for one agency
# API, or a SAML assertion for one SAML-consuming API, issued to a service provider acting for a
# person under one approval (TokenExchangeGrant), together with the refresh family the exchange
# started. One record per exchange: each refresh of the family renews this record (one more in
# `refresh_count`, the instant in `last_refreshed_at`) instead of adding a row, so `issued_at`
# and `expires_at` are the first token's and the number of tokens the family has produced is
# `refresh_count` + 1.
#
# This row is not the token. The live token is a Redis entry keyed by the token's digest with a
# TTL equal to its lifetime (DelegatedTokenStore); introspection reads that entry and an absent
# entry means the token is not active. Nothing here holds a secret and nothing reads this table
# to decide validity. The row exists for durability: billing, fraud-signal events, the account
# page and audit read it, and revocation marks it so the history shows why a token ended.
class TokenExchangeToken < ApplicationRecord
  TOKEN_FORMATS = TokenExchangeResourceServer::TOKEN_FORMATS
  # RFC 6750 bearer, RFC 9449 key-bound, or RFC 8693 §2.2.1 `N_A` for a SAML assertion.
  TOKEN_TYPES = %w[Bearer DPoP N_A].freeze

  belongs_to :grant, class_name: 'TokenExchangeGrant', inverse_of: :token_exchange_tokens
  belongs_to :resource_server, class_name: 'TokenExchangeResourceServer', inverse_of: false
  belongs_to :service_provider
  belongs_to :user

  validates :delegation_id, :scope, :refresh_family_id, :issued_at, :expires_at, presence: true
  validates :token_type, inclusion: { in: TOKEN_TYPES }
  validates :token_format, inclusion: { in: TOKEN_FORMATS }

  # Issued, not revoked and not yet expired. A row being live says nothing about whether the
  # token is still accepted; the Redis entry does.
  scope :live, -> { where(revoked_at: nil).where('expires_at > ?', Time.zone.now) }

  # The token string a service provider receives. It carries no claims; a resource server learns
  # its meaning only by introspection.
  def self.generate_token
    DelegatedAccess::OpaqueToken.generate
  end

  # Lifetime in seconds of a token issued at +now+ for +resource_server+ within a family that
  # ends at +family_expires_at+: the configured default for the format (an access token's, or the
  # shorter validity window of a SAML assertion, which the agency checks locally and which must
  # therefore die on its own soon after a revocation), or the API's own maximum when that is
  # lower, and never past the family's end, so no token outlives the family it belongs to. At
  # least one second, the smallest lifetime a live entry can be stored with.
  def self.lifetime_seconds_for(now:, resource_server:, family_expires_at:, token_format: 'oauth')
    lifetime = [
      default_lifetime_seconds(token_format),
      resource_server.max_access_token_seconds,
      (family_expires_at - now).floor,
    ].compact.min
    [lifetime, 1].max
  end

  def self.default_lifetime_seconds(token_format)
    if token_format == 'saml2'
      IdentityConfig.store.token_exchange_saml_assertion_ttl_seconds
    else
      IdentityConfig.store.token_exchange_access_token_ttl_seconds
    end
  end
  private_class_method :default_lifetime_seconds

  def saml?
    token_format == 'saml2'
  end

  # Whether every use of this token must carry a DPoP proof from the key it was bound to.
  def key_bound?
    dpop_jkt.present?
  end

  def expired?
    expires_at <= Time.zone.now
  end

  def revoked?
    revoked_at.present?
  end

  # Seconds the token lives from issuance; what the token response reports as `expires_in`.
  def lifetime_seconds
    (expires_at - issued_at).to_i
  end

  # What the live Redis entry for a token of this record's family holds (DelegatedTokenStore):
  # everything introspection reports about the token, and the ids that tie the entry back to this
  # record, its approval and its refresh family so revocation can find it. Times are epoch
  # seconds, as the entry is JSON. The record's own times are the first token's; a refresh passes
  # the new token's.
  # @param issued_at [Time] when the token was issued
  # @param expires_at [Time] when the token expires
  # @return [Hash{Symbol => Object}]
  def live_attributes(issued_at: self.issued_at, expires_at: self.expires_at)
    {
      aud: resource_server.identifier,
      scope:,
      grant_id:,
      delegation_id:,
      user_id:,
      service_provider_id:,
      resource_server_id:,
      ial:,
      aal:,
      refresh_family_id:,
      dpop_jkt:,
      token_type:,
      token_format:,
      sp_rails_session_id:,
      issued_at: issued_at.to_i,
      expires_at: expires_at.to_i,
      issuance_id: id,
    }
  end

  # Counts a refresh of the family on this record, in one statement so two refreshes committed
  # close together both count, and reloads the record.
  # @param now [Time] the instant of the refresh
  def record_refresh!(now:)
    # rubocop:disable Rails/SkipsModelValidations
    self.class.where(id:).update_all(
      ['refresh_count = refresh_count + 1, last_refreshed_at = ?, updated_at = ?', now, now],
    )
    # rubocop:enable Rails/SkipsModelValidations
    reload
  end

  def revoke!(reason:, now: Time.zone.now)
    update!(revoked_at: now, revocation_reason: reason)
  end

  # Marks every row of +relation+ that is not yet revoked as revoked now, with one reason; rows
  # already revoked keep their earlier reason. Issuance records and refresh tokens carry the same
  # two columns, so the cascades that end an approval or a refresh family share this step.
  # @param relation [ActiveRecord::Relation] of TokenExchangeToken or TokenExchangeRefreshToken
  # @return [Integer] rows updated
  def self.revoke_rows!(relation, reason:, now: Time.zone.now)
    # rubocop:disable Rails/SkipsModelValidations
    relation.where(revoked_at: nil)
      .update_all(revoked_at: now, revocation_reason: reason, updated_at: now)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
