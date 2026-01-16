class CreateDeviceProfilingResult < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    create_table :device_profiling_results do |t|
      t.references :user, null: false, foreign_key: true, comment: "sensitive=false"
      t.boolean :success, null: false, default: false, comment: "sensitive=false"
      t.string :client, comment: "sensitive=false"
      t.string :review_status, comment: "sensitive=false"
      t.string :transaction_id, comment: "sensitive=false"
      t.string :reason, comment: "sensitive=false"
      t.datetime :processed_at, comment: "sensitive=false"
      t.string :profiling_type, comment: "sensitive=false"

      t.datetime :created_at, null: false, comment: "sensitive=false"
      t.datetime :updated_at, null: false, comment: "sensitive=false"
    end
  end
end
