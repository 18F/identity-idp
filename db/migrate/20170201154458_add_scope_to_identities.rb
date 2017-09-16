class AddScopeToIdentities < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :scope, :string
  end
end
