class UpdateEmailAddressesEncryptedEmailComment < ActiveRecord::Migration[8.0]
  def change
    change_column_comment :email_addresses, :encrypted_email, to: 'sensitive=false',
                                                              from: 'sensitive=true'
  end
end
