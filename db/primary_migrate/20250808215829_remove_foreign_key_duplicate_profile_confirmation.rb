class RemoveForeignKeyDuplicateProfileConfirmation < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :duplicate_profile_confirmations, :profiles, if_exists: true
  end
end
