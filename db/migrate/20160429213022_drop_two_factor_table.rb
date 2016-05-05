class DropTwoFactorTable < ActiveRecord::Migration
  def change
    drop_table :second_factors
    drop_table :second_factors_users
    remove_column :users, :second_factor_confirmed_at
  end
end
