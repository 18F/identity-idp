class RemoveAppSetting < ActiveRecord::Migration[5.1]
  def change
    drop_table :app_settings
  end
end
