class AddCheckPasswordCompromisedAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :check_password_compromised_at, :datetime, default: nil
  end
end
