class DropJobRuns < ActiveRecord::Migration[6.1]
  def change
    drop_table :job_runs do |t|
      t.string :host, null: false
      t.string :pid, null: false
      t.datetime :finish_time
      t.string :job_name, null: false
      t.string :result
      t.string :error

      t.timestamps

      t.index %i[job_name created_at]
      t.index %i[job_name finish_time]
      t.index :error
      t.index :host
      t.index :job_name
    end
  end
end
