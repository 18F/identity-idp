class AddIdentityUuid < ActiveRecord::Migration
  def change
    add_column :identities, :uuid, :string, null: false
    add_index :identities, :uuid, unique: true
  end
end
