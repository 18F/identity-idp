class CreateSpReturnLogs < ActiveRecord::Migration[5.1]
  def change
    create_table :sp_return_logs do |t|
      t.datetime :requested_at, null: false
      t.string   :request_id, null: false
      t.integer  :ial, null: false
      t.string   :issuer, null: false
      t.integer  :user_id
      t.datetime :returned_at
    end
    add_index :sp_return_logs, %i[requested_at]
    add_index :sp_return_logs, %i[request_id], unique: true
    add_index :sp_return_logs, %i[user_id requested_at]
  end
end
