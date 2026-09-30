# frozen_string_literal: true

class AddTokenExchangeConsentAtToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :token_exchange_consent_at, :datetime,
               comment: 'sensitive=false'
  end
end
