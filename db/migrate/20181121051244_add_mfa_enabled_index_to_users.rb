class AddMfaEnabledIndexToUsers < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :users, :mfa_enabled, algorithm: :concurrently
  end
end
