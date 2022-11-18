class AddConsentedToAgencyIdentities < ActiveRecord::Migration[7.0]
  def change
    add_column :agency_identities, :consented, :boolean
  end
end
