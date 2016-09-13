class AddRecoveryCodeToUser < ActiveRecord::Migration
  def change
    add_column :users, :recovery_code, :string
  end
end
