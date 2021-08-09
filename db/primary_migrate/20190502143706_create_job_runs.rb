class CreateJobRuns < ActiveRecord::Migration[5.1]
  def change
    create_table :job_runs do |t|
      t.string :host, null: false
      t.string :pid, null: false
      t.datetime :finish_time
      t.string :job_name, null: false
      t.string :result
      t.string :error

      t.timestamps
    end

    add_index :job_runs, %i[job_name created_at]
    add_index :job_runs, %i[job_name finish_time]
    add_index :job_runs, :error
    add_index :job_runs, :host
    add_index :job_runs, :job_name
  end
end
