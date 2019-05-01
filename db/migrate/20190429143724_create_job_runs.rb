class CreateJobRuns < ActiveRecord::Migration[5.1]
  def change
    create_table :job_runs do |t|
      t.string :host
      t.string :pid
      t.datetime :start_time
      t.datetime :finish_time
      t.string :job_name
      t.string :result

      t.timestamps
    end
  end
end
