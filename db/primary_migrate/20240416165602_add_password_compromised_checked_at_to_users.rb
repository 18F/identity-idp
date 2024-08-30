class AddPasswordCompromisedCheckedAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :password_compromised_checked_at, :datetime, default: nil
  end
end
