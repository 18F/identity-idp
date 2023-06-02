class AddColumnsForUserSuspension < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :users, :suspended_at, :datetime
    add_column :users, :reinstated_at, :datetime

    add_index :users, :suspended_at, where: 'suspended_at IS NOT NULL', algorithm: :concurrently
    add_index :users, :reinstated_at, where: 'reinstated_at IS NOT NULL', algorithm: :concurrently
  end
end
