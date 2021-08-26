class CreateEmailAddressTable < ActiveRecord::Migration[5.1]
  def change
    create_table :email_addresses do |t|
      t.references :user
      t.string :confirmation_token, limit: 255
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :email_fingerprint, null: false, default: ""
      t.string :encrypted_email, null: false, default: ""

      t.timestamps

      t.index :email_fingerprint, unique: true, where: 'confirmed_at IS NOT NULL'
    end
  end
end
