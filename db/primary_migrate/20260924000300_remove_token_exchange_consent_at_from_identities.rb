# frozen_string_literal: true

class RemoveTokenExchangeConsentAtFromIdentities < ActiveRecord::Migration[8.1]
  def change
    remove_column :identities, :token_exchange_consent_at, :datetime,
                  comment: 'sensitive=false'
  end
end
