class DropGoodJobsMainDatabase < ActiveRecord::Migration[6.1]
  def change
    drop_table :good_jobs, id: :uuid do |t|
      t.text :queue_name
      t.integer :priority
      t.jsonb :serialized_params
      t.timestamp :scheduled_at
      t.timestamp :performed_at
      t.timestamp :finished_at
      t.text :error

      t.timestamps

      t.uuid :active_job_id
      t.text :concurrency_key
      t.text :cron_key

      t.index :good_jobs, :scheduled_at, where: "(finished_at IS NULL)", name: "index_good_jobs_on_scheduled_at"
      t.index :good_jobs, [:queue_name, :scheduled_at], where: "(finished_at IS NULL)", name: :index_good_jobs_on_queue_name_and_scheduled_at
      t.index :good_jobs, [:active_job_id, :created_at], name: :index_good_jobs_on_active_job_id_and_created_at
      t.index :good_jobs, :concurrency_key, where: "(finished_at IS NULL)", name: :index_good_jobs_on_concurrency_key_when_unfinished
      t.index :good_jobs, [:cron_key, :created_at], name: :index_good_jobs_on_cron_key_and_created_at    end
  end
end
