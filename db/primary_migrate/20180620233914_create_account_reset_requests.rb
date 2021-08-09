class CreateAccountResetRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :account_reset_requests do |t|
      t.integer :user_id, null: false
      t.datetime :requested_at
      t.string :request_token
      t.datetime :cancelled_at
      t.datetime :reported_fraud_at
      t.datetime :granted_at
      t.string :granted_token
      t.timestamps
      t.index ['user_id'], unique: true
      t.index ['cancelled_at','granted_at','requested_at'], name: 'index_account_reset_requests_on_timestamps'
      t.index ['request_token'], unique: true
      t.index ['granted_token'], unique: true
    end
  end
end
