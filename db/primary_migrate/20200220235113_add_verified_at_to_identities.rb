class AddVerifiedAtToIdentities < ActiveRecord::Migration[5.1]
  def change
    add_column :identities, :verified_at, :datetime
  end
end
