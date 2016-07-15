class RemoveMobileIndex < ActiveRecord::Migration
  def change
    remove_index :users, :mobile
  end
end
