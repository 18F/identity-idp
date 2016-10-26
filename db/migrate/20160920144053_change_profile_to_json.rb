class ChangeProfileToJson < ActiveRecord::Migration
  class Profile < ActiveRecord::Base
  end

  def up
    add_column :profiles, :encrypted_pii, :text
    Profile.all.each do |profile|
      pii = {
        first_name: profile.first_name,
        middle_name: profile.middle_name,
        last_name: profile.last_name,
        address1: profile.address1,
        address2: profile.address2,
        city: profile.city,
        state: profile.state,
        zipcode: profile.zipcode,
        ssn: profile.ssn,
        dob: profile.dob.to_s,
        phone: profile.phone
      }
      profile.update!(encrypted_pii: pii.to_json, active: false)
    end
    remove_index :profiles, [:ssn, :active]
    change_table :profiles do |tbl|
      tbl.remove :first_name, :middle_name, :last_name, :address1, :address2, :city, :state, :zipcode
      tbl.remove :ssn, :dob, :phone
    end
  end

  def down
    change_table :profiles do |tbl|
      tbl.string :first_name, :middle_name, :last_name, :address1, :address2, :city, :state, :zipcode
      tbl.string :ssn, :phone
      tbl.date :dob
    end
    Profile.all.each do |profile|
      pii = JSON.parse(profile.encrypted_pii, symbolize_names: true)
      profile.update!(pii)
    end
    change_table :profiles do |tbl|
      tbl.remove :encrypted_pii
    end
    add_index :profiles, [:ssn, :active], unique: true, where: "(active = true)", using: :btree
  end
end
