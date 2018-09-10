class DropPersonalKeyColumnsFromUser < ActiveRecord::Migration[5.1]
  def up
    safety_assured do
      remove_column :users, :recovery_code
      remove_column :users, :encryption_key
      remove_column :users, :recovery_salt
      remove_column :users, :recovery_cost
    end
  end

  def down
    add_column :users, :recovery_code, :string
    add_column :users, :encryption_key, :string
    add_column :users, :recovery_salt, :string
    add_column :users, :recovery_cost, :string
  end
end
