# frozen_string_literal: true

# Immutable history of delegated access tokens issued by Login.gov. Each row represents one
# DAT mint and links the actor's browser handoff to the target agency's billable return log.
class CreateDelegatedIssuances < ActiveRecord::Migration[8.1]
  def change
    create_table :delegated_issuances do |t|
      t.string :delegation_id, null: false, comment: 'sensitive=false'
      t.bigint :user_id, null: false, comment: 'sensitive=false'
      t.bigint :actor_return_log_id, null: false, comment: 'sensitive=false'
      t.bigint :target_return_log_id, null: false, comment: 'sensitive=false'
      t.string :actor_issuer, null: false, comment: 'sensitive=false'
      t.string :target_issuer, null: false, comment: 'sensitive=false'
      t.string :resource, null: false, comment: 'sensitive=false'
      t.string :scope, comment: 'sensitive=false'
      t.datetime :issued_at, null: false, comment: 'sensitive=false'
      t.datetime :expires_at, null: false, comment: 'sensitive=false'
      t.timestamps comment: 'sensitive=false'

      t.index :delegation_id, unique: true
      t.index :user_id
      t.index :actor_return_log_id
      t.index :target_return_log_id, unique: true
      t.index %i[user_id target_issuer issued_at],
              name: 'idx_delegated_issuances_user_target_issued'
      t.index %i[user_id actor_issuer issued_at],
              name: 'idx_delegated_issuances_user_actor_issued'
    end

    add_foreign_key :delegated_issuances, :sp_return_logs,
                    column: :actor_return_log_id, validate: false
    add_foreign_key :delegated_issuances, :sp_return_logs,
                    column: :target_return_log_id, validate: false
  end
end
