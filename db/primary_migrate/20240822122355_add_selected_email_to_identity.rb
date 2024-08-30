class AddSelectedEmailToIdentity < ActiveRecord::Migration[7.1]
  def change
    add_column :identities, :email_address_id, :bigint
  end
end
