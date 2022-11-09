class CreateIrsAttemptApiLogFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :irs_attempt_api_log_files do |t|
      t.string :filename
      t.string :iv
      t.text :encrypted_key
      t.datetime :requested_time

      t.timestamps
    end
  end
end
