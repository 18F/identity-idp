class AddPiiTable < ActiveRecord::Migration
  # rubocop:disable AbcSize, MethodLength
  def up
    create_table :piis do |tbl|
      tbl.integer :user_id, null: false
      tbl.boolean :active, null: false, default: false
      tbl.boolean :verified, null: false, default: false
      tbl.timestamps null: false

      tbl.string :first_name
      tbl.string :middle_name
      tbl.string :last_name
      tbl.string :gen
      tbl.string :address1
      tbl.string :address2
      tbl.string :city
      tbl.string :state
      tbl.string :zipcode
      tbl.string :ssn
      tbl.string :dob
      tbl.string :phone
      tbl.string :drivers_license_state
      tbl.string :drivers_license_id
      tbl.string :passport_id
      tbl.string :military_id
    end

    add_index :piis, :user_id
    # https://www.postgresql.org/docs/current/static/indexes-partial.html
    execute('create unique index piis_active_user_idx on piis(user_id, active) where active=true')
  end
  # rubocop:enable AbcSize, MethodLength

  def down
    remove_index :piis, :user_id
    execute('drop index piis_active_user_idx')
    drop_table :piis
  end
end
