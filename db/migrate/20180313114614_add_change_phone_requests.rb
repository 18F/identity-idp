class AddChangePhoneRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :change_phone_requests do |t|
      t.integer :user_id, null: false
      t.datetime :requested_at
      t.string :request_token
      t.integer :request_count, default: 0
      t.datetime :cancelled_at
      t.integer :cancel_count, default: 0
      t.datetime :reported_fraud_at
      t.integer :reported_fraud_count, default: 0
      t.datetime :granted_at
      t.string :granted_token
      t.boolean :security_answer_correct
      t.integer :wrong_answer_count, default: 0
      t.datetime :answered_at
      t.integer :phone_changed_count, default: 0
      t.timestamps
      t.index ['user_id'], name: 'index_change_phone_requests_on_user_id', unique: true
      t.index ['cancelled_at','granted_at','requested_at'], name: 'index_change_phone_requests_on_cancel_request_and_granted_at'
      t.index ['request_token'], name: 'index_change_phone_requests_on_request_token', unique: true
      t.index ['granted_token'], name: 'index_change_phone_requests_on_granted_token', unique: true
    end
  end
end
