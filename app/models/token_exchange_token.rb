# frozen_string_literal: true

# The issuance record of one delegated token: an opaque access token for one agency API, or a
# SAML assertion for one SAML-consuming API, issued to a service provider acting for a person
# under one approval (TokenExchangeGrant).
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

  def revoke!(reason:, now: Time.zone.now)
    update!(revoked_at: now, revocation_reason: reason)
  end
end
