class DropDuplicateProfileConfirmations < ActiveRecord::Migration[8.0]
  def change
    drop_table :duplicate_profile_confirmations, if_exists: true
  end
end
