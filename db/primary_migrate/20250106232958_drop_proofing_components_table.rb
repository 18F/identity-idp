class DropProofingComponentsTable < ActiveRecord::Migration[7.2]
  def change
    drop_table :proofing_components
  end
end
