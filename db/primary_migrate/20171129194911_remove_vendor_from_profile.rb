class RemoveVendorFromProfile < ActiveRecord::Migration[5.1]
  def change
    remove_column :profiles, :vendor, :string
  end
end
