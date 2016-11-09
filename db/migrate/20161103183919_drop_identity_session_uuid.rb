class DropIdentitySessionUuid < ActiveRecord::Migration
  def change
    remove_column :identities, :session_uuid
    add_column :sessions, :uuid, :string
  end
end
