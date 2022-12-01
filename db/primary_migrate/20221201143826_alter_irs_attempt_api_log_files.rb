class AlterIrsAttemptApiLogFiles < ActiveRecord::Migration[7.0]
  def change
    change_column :irs_attempt_api_log_files, :requested_time, :string
  end
end