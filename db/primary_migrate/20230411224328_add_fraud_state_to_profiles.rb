class AddFraudStateToProfiles < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :fraud_state, :string
  end
end
