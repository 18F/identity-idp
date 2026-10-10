# frozen_string_literal: true

# The nightly purge of refresh-token rows selects by the family's end (expires_at).
class AddExpiresAtIndexToTokenExchangeRefreshTokens < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :token_exchange_refresh_tokens, :expires_at, algorithm: :concurrently
  end
end
