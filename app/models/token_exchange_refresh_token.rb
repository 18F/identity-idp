# frozen_string_literal: true

# A refresh token of a delegated-access family: the credential a service provider presents at the
# token endpoint (RFC 6749 §6) to obtain the next access token for the same API, same scope and
# same approval, without involving the person.
#
# A family is the chain of tokens one exchange starts. It has an absolute end, fixed at the
# exchange and copied to every row of the family (#expires_at): the shortest of the configured
# default, the API's own limit, the service provider's own limit, and the moment the person's
# remembered approval ends. Nothing a service provider does moves it.
#
# Each refresh rotates the token (RFC 9700 §4.14.2): the presented row is marked rotated and a new
# row with the same family id and the same end is written. A rotated token presented again means
# the service provider replayed it or someone else holds a copy; either way the whole family is
# revoked, so a stolen refresh token costs the holder the access rather than extending it.
#
# Only the SHA-256 digest of the token string is stored. The plaintext exists in the token
# response and nowhere else. The rows are operational state, not evidence: once a family has
# ended they serve nothing, and ExpireDelegatedRefreshTokensJob deletes them a day after the end
# (#expired_for_purge). The family's issuance record (TokenExchangeToken) is what stays.
class TokenExchangeRefreshToken < ApplicationRecord
  belongs_to :grant, class_name: 'TokenExchangeGrant', inverse_of: :token_exchange_refresh_tokens
  # The family's issuance record: written by the exchange that started the family and renewed by
  # each refresh, so every refresh token of a family points at the same record.
  belongs_to :token_exchange_token, inverse_of: false
  belongs_to :resource_server, class_name: 'TokenExchangeResourceServer', inverse_of: false
  belongs_to :service_provider
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :family_id, :scope, :expires_at, presence: true

  # Usable: not rotated, not revoked and the family has not ended.
  scope :live, -> { where(rotated_at: nil, revoked_at: nil).where('expires_at > ?', Time.zone.now) }
  scope :for_family, ->(family_id) { where(family_id:) }
  # Rows whose family ended more than a day ago, which the nightly purge deletes. No refresh under
  # an ended family can succeed, and a day past the end a replay of one of its tokens has nothing
  # left to end, so the rows carry no further state.
  scope :expired_for_purge, -> { where('expires_at < ?', 1.day.ago) }

  # The token string a service provider receives.
  def self.generate_token
    DelegatedAccess::OpaqueToken.generate
  end

  # @param token [String] the token string as presented by a caller
  # @return [String] hex SHA-256 digest; the stored lookup key
  def self.digest(token)
    DelegatedAccess::OpaqueToken.digest(token)
  end

  # @param token [String, nil] the token string as presented by a caller
  # @return [TokenExchangeRefreshToken, nil] the row for that token, whatever its state
  def self.lookup(token)
    return nil if token.blank? || token.include?("\x00")

    find_by(token_digest: digest(token))
  end

  # When a family started at +from+ must end: the shortest of the configured default lifetime,
  # the API's own limit and the service provider's own limit, counted from +from+, and never
  # later than the end of the person's remembered approval. A limit can only shorten the family;
  # a limit longer than the default has no effect.
  #
  # @param from [Time] the instant of the exchange that starts the family
  # @param grant [TokenExchangeGrant]
  # @param resource_server [TokenExchangeResourceServer]
  # @param service_provider [ServiceProvider]
  # @return [Time]
  def self.family_end(from:, grant:, resource_server:, service_provider:)
    lifetime = [
      IdentityConfig.store.token_exchange_refresh_token_ttl_seconds,
      resource_server.max_family_seconds,
      service_provider.delegation_max_family_seconds,
    ].compact.min
    [from + lifetime.seconds, grant.remember_until].compact.min
  end

  # Ends a whole family at once: the live access tokens listed in the family's Redis index set
  # are removed, so a resource server verifying one is told it is not active from the next call,
  # and the family's refresh tokens and issuance records are marked revoked with the reason so
  # the history shows why the access ended. Rows already revoked keep their earlier reason. A
  # family belongs to one approval, whose rows are the ones marked.
  # @param family_id [String]
  # @param grant [TokenExchangeGrant] the approval the family was opened under
  def self.revoke_family!(family_id, grant:, reason:, now: Time.zone.now)
    DelegatedTokenStore.revoke_family(family_id)
    TokenExchangeToken.revoke_rows!(
      grant.token_exchange_refresh_tokens.for_family(family_id), reason:, now:
    )
    TokenExchangeToken.revoke_rows!(
      grant.token_exchange_tokens.where(refresh_family_id: family_id), reason:, now:
    )
  end

  # Whether the family is bound to a key, in which case every refresh must carry a DPoP proof
  # from that key.
  def key_bound?
    dpop_jkt.present?
  end

  def rotated?
    rotated_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  # Whether the family has reached its absolute end.
  def family_ended?(now: Time.zone.now)
    expires_at <= now
  end

  # Seconds until the family ends, never negative; what the token response reports as
  # `refresh_token_expires_in`.
  def seconds_until_family_end(now: Time.zone.now)
    [(expires_at - now).floor, 0].max
  end
end
