class AddVotAndAcrToIdentities < ActiveRecord::Migration[7.1]
  def change
    add_column :identities, :acr, :string
    add_column :identities, :vot, :string
  end
end
