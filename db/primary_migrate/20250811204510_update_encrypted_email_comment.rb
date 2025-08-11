class UpdateEncryptedEmailComment < ActiveRecord::Migration[8.0]
  def change
    change_column_comment :email_addresses, :encrypted_email, "sensitive=false"
  end
end
