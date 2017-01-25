class AddIalToIdentitiesAgain < ActiveRecord::Migration
  def change
    add_column :identities, :ial, :integer, default: 1
  end
end
