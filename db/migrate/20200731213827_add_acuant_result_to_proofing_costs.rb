class AddAcuantResultToProofingCosts < ActiveRecord::Migration[5.2]
  def change
    add_column :proofing_costs, :acuant_result_count, :integer, default: 0
  end
end
