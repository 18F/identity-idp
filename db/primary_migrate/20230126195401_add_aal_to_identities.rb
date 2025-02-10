class AddAalToIdentities < ActiveRecord::Migration[7.0]
  def change
    add_column :identities, :aal, :integer
  end
end
