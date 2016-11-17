class AddUserPasswordCost < ActiveRecord::Migration
  def change
    add_column :users, :password_cost, :string
  end
end
