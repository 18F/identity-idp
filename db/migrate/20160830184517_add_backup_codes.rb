class AddBackupCodes < ActiveRecord::Migration
  def change
    add_column :users, :backup_codes, :string
    add_column :users, :backup_codes_downloaded, :boolean
  end
end
