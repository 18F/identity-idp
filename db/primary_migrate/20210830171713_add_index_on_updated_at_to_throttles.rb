class AddIndexOnUpdatedAtToThrottles < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :throttles, [:updated_at], algorithm: :concurrently
  end
end
