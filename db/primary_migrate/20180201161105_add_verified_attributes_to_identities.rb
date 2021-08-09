class AddVerifiedAttributesToIdentities < ActiveRecord::Migration[5.1]
  def up
    add_column :identities, :verified_attributes, :json
  end

  def down
    remove_column :identities, :verified_attributes, :json
  end
end
