class CreateJobRuns < ActiveRecord::Migration[5.1]
  def change
    create_table :job_runs do |t|
      t.string :host, null: false
      t.string :pid, null: false
      t.datetime :finish_time
      t.string :job_name, null: false
      t.string :result
      t.boolean :errored

      t.timestamps
    end
    add_index :job_runs, :host
    add_index :job_runs, [:job_name, :created_at, :finish_time]
    add_index :job_runs, [:created_at, :errored]
  end
end
