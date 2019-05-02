class CreateJobRuns < ActiveRecord::Migration[5.1]
  def change
    create_table :job_runs do |t|
      t.string :host, null: false
      t.string :pid, null: false
      t.datetime :start_time, null: false
      t.datetime :finish_time, null: true
      t.string :job_name, null: false
      t.string :result, null: true

      t.timestamps
    end
    add_index :job_runs, :pid
    add_index :job_runs, :job_name
  end
end
