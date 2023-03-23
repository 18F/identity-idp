class CreateFraudEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :fraud_events do |t|
      t.integer :user_id
      t.string :irs_session_id
      t.string :login_session_id

      t.timestamps
    end
  end
end
