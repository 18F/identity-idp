class AddIdvAttemptsToUser < ActiveRecord::Migration
  def change
    add_column :users, :idv_attempts, :integer, default: 0
  end
end
