# frozen_string_literal: true

# The issuance record of delegated tokens: one row per access token or SAML assertion Login.gov
# issues to a service provider for one agency API. The live token itself is a Redis entry keyed
# by the token's SHA-256 digest with a TTL equal to its lifetime (see DelegatedTokenStore);
# nothing in this table decides whether a token is valid and no secret is stored here. The rows
# serve billing, fraud-signal events, the account page and audit, and are marked revoked when a
# grant or a refresh family is revoked.
#
# Columns:
# * grant_id: the approval the token was issued under (token_exchange_grants).
# * resource_server_id: the API URL the token is for (its audience).
# * service_provider_id: the service provider acting for the person.
# * user_id: the person.
# * delegation_id: copied from the grant so reports join without touching it.
# * scope: the `token_exchange:<value>` scope of the application the API belongs to.
# * ial / aal: the identity and authentication assurance forwarded from the service provider's
#   sign-in.
# * refresh_family_id: identifies the chain of tokens one exchange starts.
# * token_type: Bearer, DPoP (key-bound) or N_A (a SAML assertion).
# * token_format: oauth (opaque access token) or saml2 (assertion).
# * dpop_jkt: RFC 7638 thumbprint of the key a DPoP token is bound to; null for a bearer token.
# * sp_rails_session_id: the browser session the service provider's sign-in ran in, for audit
#   and live fraud-signal events only; never read to decide validity. A session key, so marked
#   sensitive.
# * issued_at / expires_at: the token's lifetime.
# * revoked_at / revocation_reason: set when a revocation cascades to this token.
class CreateTokenExchangeTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :token_exchange_tokens do |t|
      t.bigint :grant_id, null: false, comment: 'sensitive=false'
      t.bigint :resource_server_id, null: false, comment: 'sensitive=false'
      t.bigint :service_provider_id, null: false, comment: 'sensitive=false'
      t.bigint :user_id, null: false, comment: 'sensitive=false'
      t.string :delegation_id, null: false, comment: 'sensitive=false'
      t.string :scope, null: false, comment: 'sensitive=false'
      t.integer :ial, comment: 'sensitive=false'
      t.integer :aal, comment: 'sensitive=false'
      t.string :refresh_family_id, null: false, comment: 'sensitive=false'
      t.string :token_type, null: false, comment: 'sensitive=false'
      t.string :token_format, null: false, default: 'oauth', comment: 'sensitive=false'
      t.string :dpop_jkt, comment: 'sensitive=false'
      t.string :sp_rails_session_id, comment: 'sensitive=true'
      t.datetime :issued_at, null: false, comment: 'sensitive=false'
      t.datetime :expires_at, null: false, comment: 'sensitive=false'
      t.datetime :revoked_at, comment: 'sensitive=false'
      t.string :revocation_reason, comment: 'sensitive=false'
      t.timestamps comment: 'sensitive=false'

      t.index :grant_id
      t.index :refresh_family_id
      t.index :user_id
      t.index :resource_server_id
      t.index :service_provider_id
    end
  end
end
