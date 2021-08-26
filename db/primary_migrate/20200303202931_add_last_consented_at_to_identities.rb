class AddLastConsentedAtToIdentities < ActiveRecord::Migration[5.1]
  def change
    add_column :identities, :last_consented_at, :datetime, null: true
  end
end
