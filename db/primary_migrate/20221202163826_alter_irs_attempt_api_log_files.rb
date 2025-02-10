class AlterIrsAttemptApiLogFiles < ActiveRecord::Migration[7.0]
    def up
      safety_assured { remove_column :irs_attempt_api_log_files, :requested_time, :datetime }
      add_column :irs_attempt_api_log_files, :requested_time, :string
    end
  
    def down
      safety_assured { remove_column :irs_attempt_api_log_files, :requested_time, :string }
      add_column :irs_attempt_api_log_files, :requested_time, :datetime
    end
  end