class AddRecoverySalt < ActiveRecord::Migration
  def change
    add_column :users, :recovery_salt, :string
  end
end
