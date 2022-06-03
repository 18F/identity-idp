class DropDeprecatedUserColumns < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    remove_index :users, column: [:confirmation_token], name: 'index_users_on_confirmation_token', algorithm: :concurrently

    safety_assured do
      remove_column :users, :confirmation_token
      remove_column :users, :confirmation_sent_at
    end
  end

  def down
    add_column :users, :confirmation_token, :text
    add_column :users, :confirmation_sent_at, :datetime

    add_index :users, ['confirmation_token'], name: 'index_users_on_confirmation_token', unique: true
  end
end
