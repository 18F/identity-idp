class DropUsersEmailColumns < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      remove_column :users, :encrypted_email, type: :text, default: '', null: false
      remove_column :users, :email_fingerprint, type: :text, default: '', null: false
    end
  end
end
