class AddScopeToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :scope, :string
  end
end
