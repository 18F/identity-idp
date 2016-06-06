class AddIalToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :ial, :integer, default: 1

    add_index :identities, :ial
  end
end
