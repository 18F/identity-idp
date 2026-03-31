# frozen_string_literal: true

class AllowNullServiceProviderOnDuplicateProfileSets < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    change_column_null :duplicate_profile_sets, :service_provider, true

    # Add index where SP is null
    add_index :duplicate_profile_sets, :profile_ids,
              unique: true,
              where: 'service_provider IS NULL',
              name: 'index_duplicate_profile_sets_on_profile_ids_sp_null',
              algorithm: :concurrently
  end

  def down
    remove_index :duplicate_profile_sets,
                 name: 'index_duplicate_profile_sets_on_profile_ids_sp_null',
                 algorithm: :concurrently

    # Backfill any null service_provider rows before re-adding the constraint
    DuplicateProfileSet.where(service_provider: nil).update_all(service_provider: 'unknown')
    change_column_null :duplicate_profile_sets, :service_provider, false
  end
end
