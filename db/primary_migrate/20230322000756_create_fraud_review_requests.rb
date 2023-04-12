class CreateFraudReviewRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :fraud_review_requests do |t|
      t.integer :user_id
      t.string :uuid
      t.string :irs_session_id
      t.string :login_session_id

      t.timestamps

      t.index :user_id, unique: false
    end
  end
end
