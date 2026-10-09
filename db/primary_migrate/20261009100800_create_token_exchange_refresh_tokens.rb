# frozen_string_literal: true

# Refresh tokens for delegated access: the credential a service provider presents at the token
# endpoint to obtain the next access token for the same API without involving the person.
#
# A refresh token is an opaque random string. Only its SHA-256 digest is stored, so a copy of this
# table yields no usable credential; the plaintext exists in the token response and nowhere else.
# Every refresh rotates the token: the presented row is marked rotated and a new row with the
# same family id is written. A rotated token presented again is a reuse and ends the family.
#
# Columns:
# * token_digest: hex SHA-256 of the token string; the lookup key.
# * family_id: the chain of tokens one exchange started (token_exchange_tokens.refresh_family_id).
# * grant_id: the approval the family was issued under (token_exchange_grants).
# * token_exchange_token_id: the issuance record of the access token this refresh token was
#   issued alongside.
# * resource_server_id, service_provider_id, user_id: copied from the family so ownership and
#   cascade checks need no join.
# * scope: copied from the family; a refresh cannot change it.
# * dpop_jkt: RFC 7638 thumbprint of the key the family is bound to; null for a bearer family.
#   A refresh of a bound family must carry a proof from this key.
# * expires_at: the absolute end of the family. Every row of one family carries the same value;
#   no refresh moves it.
# * used_at: when the token was last presented at the token endpoint, including a reuse attempt.
# * rotated_at: when the token was consumed by a successful refresh; non-null means spent.
# * revoked_at / revocation_reason: set when the family or its grant is revoked.
class CreateTokenExchangeRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :token_exchange_refresh_tokens do |t|
      t.string :token_digest, null: false, comment: 'sensitive=false'
      t.string :family_id, null: false, comment: 'sensitive=false'
      t.bigint :grant_id, null: false, comment: 'sensitive=false'
      t.bigint :token_exchange_token_id, null: false, comment: 'sensitive=false'
      t.bigint :resource_server_id, null: false, comment: 'sensitive=false'
      t.bigint :service_provider_id, null: false, comment: 'sensitive=false'
      t.bigint :user_id, null: false, comment: 'sensitive=false'
      t.string :scope, null: false, comment: 'sensitive=false'
      t.string :dpop_jkt, comment: 'sensitive=false'
      t.datetime :expires_at, null: false, comment: 'sensitive=false'
      t.datetime :used_at, comment: 'sensitive=false'
      t.datetime :rotated_at, comment: 'sensitive=false'
      t.datetime :revoked_at, comment: 'sensitive=false'
      t.string :revocation_reason, comment: 'sensitive=false'
      t.timestamps comment: 'sensitive=false'

      t.index :token_digest, unique: true
      t.index :family_id
      t.index :grant_id
      t.index :token_exchange_token_id
      t.index :user_id
      t.index :service_provider_id
    end
  end
end
