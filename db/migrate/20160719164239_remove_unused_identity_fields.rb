class RemoveUnusedIdentityFields < ActiveRecord::Migration
  def change
    remove_column :identities, :quiz_started
    remove_column :identities, :session_index
  end
end
