# frozen_string_literal: true

class CreateAccountRecoveryRequestsWithRecoveryStates < ActiveRecord::Migration[8.1]
  def change
    create_table :account_recovery_requests do |t|
      t.integer :user_id, null: false, comment: 'sensitive=false'
      t.string :state, null: false, comment: 'sensitive=false'

      t.datetime :requested_at, comment: 'sensitive=false'
      t.datetime :granted_at, comment: 'sensitive=false'
      t.datetime :link_verified_at, comment: 'sensitive=false'
      t.datetime :password_verified_at, comment: 'sensitive=false'
      t.datetime :completed_at, comment: 'sensitive=false'
      t.datetime :cancelled_at, comment: 'sensitive=false'
      t.datetime :expired_at, comment: 'sensitive=false'

      t.string :token_fingerprint, comment: 'sensitive=true'
      t.datetime :token_expires_at, comment: 'sensitive=false'

      t.string :cancel_reason, comment: 'sensitive=false'
      t.string :failure_reason, comment: 'sensitive=false'

      t.timestamps comment: 'sensitive=false'
    end

    add_index :account_recovery_requests, :user_id
    add_index :account_recovery_requests,
              :user_id,
              unique: true,
              where: 'completed_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL',
              name: 'index_account_recovery_requests_on_active_user_id'
  end
end
