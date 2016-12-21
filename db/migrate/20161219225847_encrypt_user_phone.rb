class EncryptUserPhone < ActiveRecord::Migration
  class User < ActiveRecord::Base
  end

  def up
    encrypt_phone
    rename_column :users, :phone, :phone_plain
  end

  def down
    rename_column :users, :phone_plain, :phone
  end

  def encrypt_phone
    User.where.not(phone: nil).find_in_batches.with_index do |users, batch|
      users.each do |user|
        ephone = EncryptedAttribute.new_from_decrypted(user.phone)
        # must use raw SQL here to change data during the migration transaction.
        execute "UPDATE users SET encrypted_phone='#{ephone.encrypted}' WHERE id=#{user.id}"
      end
    end
  end
end
