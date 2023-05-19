class AddFraudStateToProfiles < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :profiles, :fraud_state, :string

    add_index :profiles, :fraud_state, algorithm: :concurrently
  end
end
