class AddIndexToProfilesOnActiveAndIdvLevel < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :profiles, %i[active idv_level verified_at], algorithm: :concurrently, name: 'index_profiles_on_active_and_idv_level_and_verified_at'
  end
end
