class RemoveUnconfirmedMobile < ActiveRecord::Migration
  def change
    remove_column :users, :unconfirmed_mobile
  end
end
