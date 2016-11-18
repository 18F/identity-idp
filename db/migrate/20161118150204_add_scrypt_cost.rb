class AddScryptCost < ActiveRecord::Migration
  def up
    add_column :users, :password_cost, :string
    add_column :users, :recovery_cost, :string
    backfill
  end

  def down
    remove_column :users, :password_cost
    remove_column :users, :recovery_cost
  end

  def backfill
    cost = Figaro.env.scrypt_cost
    User.where(password_cost: nil).each do |user|
      user.update!(password_cost: cost, recovery_cost: cost)
    end
  end
end
