class DropEmailAddressesUserIdLastSignInAtDescIndex < ActiveRecord::Migration[7.0]
  def change
    remove_index :email_addresses, name: "index_email_addresses_on_user_id_and_last_sign_in_at"
  end
end
