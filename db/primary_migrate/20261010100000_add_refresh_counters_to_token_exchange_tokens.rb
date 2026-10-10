# frozen_string_literal: true

# One issuance record stands for every token of a refresh family: the exchange writes it and each
# refresh renews it instead of adding a row, so the table holds one row per exchange whatever the
# number of refreshes.
#
# * refresh_count: how many times the family has been refreshed.
# * last_refreshed_at: when the family was last refreshed; null for a family never refreshed.
class AddRefreshCountersToTokenExchangeTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :token_exchange_tokens, :refresh_count, :integer,
               null: false, default: 0, comment: 'sensitive=false'
    add_column :token_exchange_tokens, :last_refreshed_at, :datetime, comment: 'sensitive=false'
  end
end
