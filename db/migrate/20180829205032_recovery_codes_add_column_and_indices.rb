class RecoveryCodesAddColumnAndIndices < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!
  def change
    add_index :recovery_codes, :user_id, algorithm: :concurrently
    add_column :recovery_codes, :when_user, :timestamp
  end
end
