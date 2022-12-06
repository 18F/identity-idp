class AlterIrsAttemptApiLogFiles < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :irs_attempt_api_log_files, :requested_time, :datetime }
  end
end