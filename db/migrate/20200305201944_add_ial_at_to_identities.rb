class AddIalAtToIdentities < ActiveRecord::Migration[5.1]
  def change
    add_column :identities, :last_ial1_authenticated_at, :datetime
    add_column :identities, :last_ial2_authenticated_at, :datetime
  end
end
