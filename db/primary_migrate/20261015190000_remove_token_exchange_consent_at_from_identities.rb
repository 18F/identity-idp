class RemoveTokenExchangeConsentAtFromIdentities < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :identities, :token_exchange_consent_at, :datetime,
                    comment: 'sensitive=false'
    end
  end
end
