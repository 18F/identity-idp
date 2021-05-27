class AddIndexOnReproofAtToProfiles < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :profiles, [:reproof_at], algorithm: :concurrently
  end
end
