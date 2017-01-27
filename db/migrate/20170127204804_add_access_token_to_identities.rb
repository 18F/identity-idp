class AddAccessTokenToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :access_token, :string

    add_index :identities, :access_token, unique: true
  end
end
