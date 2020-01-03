class DropX509DnUuidColumnFromUser < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      remove_column :users, :x509_dn_uuid
    end
  end
end
