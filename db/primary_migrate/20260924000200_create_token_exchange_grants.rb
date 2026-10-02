# frozen_string_literal: true

class CreateTokenExchangeGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :token_exchange_grants, comment: 'sensitive=false' do |t|
      t.references :user, null: false, foreign_key: true, comment: 'sensitive=false'
      t.string :broker_issuer, null: false, comment: 'sensitive=false'
      t.string :target_issuer, null: false, comment: 'sensitive=false'
      t.boolean :includes_future, null: false, default: false, comment: 'sensitive=false'
      t.datetime :granted_at, null: false, comment: 'sensitive=false'
      t.datetime :expires_at, null: false, comment: 'sensitive=false'
      t.datetime :revoked_at, comment: 'sensitive=false'
      t.timestamps comment: 'sensitive=false'
    end

    add_index :token_exchange_grants, %i[user_id broker_issuer target_issuer],
              unique: true, name: 'index_token_exchange_grants_on_user_broker_target'
  end
end
