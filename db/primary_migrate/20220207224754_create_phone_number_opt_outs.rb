class CreatePhoneNumberOptOuts < ActiveRecord::Migration[6.1]
  def change
    create_table :phone_number_opt_outs do |t|
      t.string :encrypted_phone
      t.string :phone_fingerprint, null: false
      t.string :uuid

      t.timestamps
    end

    add_index :phone_number_opt_outs, :phone_fingerprint, unique: true
    add_index :phone_number_opt_outs, :uuid, unique: true
  end
end
