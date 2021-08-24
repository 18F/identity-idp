class AddTargetIndexToThrottles < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :throttles, [:target, :throttle_type], algorithm: :concurrently
  end
end
