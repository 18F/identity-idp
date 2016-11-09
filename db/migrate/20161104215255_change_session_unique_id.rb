class ChangeSessionUniqueId < ActiveRecord::Migration
  def change
    remove_index :sessions, [:session_id] # unique
    add_index :sessions, [:session_id, :identity_id], unique: true
    add_index :sessions, [:session_id] # not unique
  end
end
