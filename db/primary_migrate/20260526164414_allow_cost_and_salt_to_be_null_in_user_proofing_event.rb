class AllowCostAndSaltToBeNullInUserProofingEvent < ActiveRecord::Migration[8.0]
  def up
    change_column :user_proofing_events, :cost, :string, null: true
    change_column :user_proofing_events, :salt, :string, null: true
  end

  def down
    change_column :user_proofing_events, :cost, :string, null: false
    change_column :user_proofing_events, :salt, :string, null: false
  end
end
