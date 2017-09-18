class AddAccessTokenToIdentities < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :access_token, :string

    add_index :identities, :access_token, unique: true
  end
end
