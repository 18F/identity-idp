class AddIalToIdentitiesAgain < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :ial, :integer, default: 1
  end
end
