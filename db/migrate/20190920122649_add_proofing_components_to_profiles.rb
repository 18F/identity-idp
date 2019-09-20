class AddProofingComponentsToProfiles < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :profiles, :proofing_components, :jsonb
  end
end
