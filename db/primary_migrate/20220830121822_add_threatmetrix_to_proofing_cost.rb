class AddThreatmetrixToProofingCost < ActiveRecord::Migration[7.0]
  def up
    add_column :proofing_costs, :threatmetrix_count, :integer
    change_column_default :proofing_costs, :threatmetrix_count, 0
  end

  def down
    remove_column :proofing_costs, :threatmetrix_count
  end
end
