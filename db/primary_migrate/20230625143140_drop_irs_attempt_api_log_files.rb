class DropIrsAttemptApiLogFiles < ActiveRecord::Migration[7.0]
  def change
    drop_table :irs_attempt_api_log_files
  end
end
