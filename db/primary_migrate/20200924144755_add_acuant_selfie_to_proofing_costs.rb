class AddAcuantSelfieToProofingCosts < ActiveRecord::Migration[5.2]
  def up
    add_column :proofing_costs, :acuant_selfie_count, :integer
    change_column_default :proofing_costs, :acuant_selfie_count, 0
  end

  def down
    remove_column :proofing_costs, :acuant_selfie_count
  end
end
