# frozen_string_literal: true

# Refresh tokens a token exchange actor uses to get a new subject token without sending the
# person back through sign-in. Each row is one refresh token; rotation adds a row to the same
# family, so a family is one sign-in's chain of refresh tokens. Only the token's digest is stored.
class CreateTokenExchangeRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :token_exchange_refresh_tokens do |t|
      t.string :token_digest, null: false, comment: 'sensitive=true'
      t.string :family_id, null: false, comment: 'sensitive=false'
      t.bigint :user_id, null: false, comment: 'sensitive=false'
      t.string :actor_issuer, null: false, comment: 'sensitive=false'
      t.string :identity_uuid, null: false, comment: 'sensitive=false'
      t.string :scope, comment: 'sensitive=false'
      t.integer :ial, comment: 'sensitive=false'
      t.bigint :actor_return_log_id, comment: 'sensitive=false'
      t.string :resource, comment: 'sensitive=false'
      t.string :dpop_jkt, null: false, comment: 'sensitive=false'
      t.datetime :authenticated_at, null: false, comment: 'sensitive=false'
      t.datetime :family_expires_at, null: false, comment: 'sensitive=false'
      t.datetime :expires_at, null: false, comment: 'sensitive=false'
      t.datetime :used_at, comment: 'sensitive=false'
      t.datetime :revoked_at, comment: 'sensitive=false'
      t.string :revocation_reason, comment: 'sensitive=false'
      t.timestamps comment: 'sensitive=false'

      t.index :token_digest, unique: true
      t.index :family_id
      t.index %i[user_id actor_issuer], name: 'idx_te_refresh_tokens_user_actor'
      t.index :family_expires_at
    end
  end
end
