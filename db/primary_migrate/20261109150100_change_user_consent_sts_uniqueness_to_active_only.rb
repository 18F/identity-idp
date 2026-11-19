# frozen_string_literal: true

class ChangeUserConsentStsUniquenessToActiveOnly < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :user_consent_sts,
                 name: 'index_user_consent_sts_on_user_id_and_target_app',
                 algorithm: :concurrently
    add_index :user_consent_sts, [:user_id, :target_app, :actor_app],
              unique: true, where: '(NOT is_revoked)', algorithm: :concurrently,
              name: 'index_user_consent_sts_on_active_user_target_actor'
  end

  def down
    remove_index :user_consent_sts,
                 name: 'index_user_consent_sts_on_active_user_target_actor',
                 algorithm: :concurrently
    add_index :user_consent_sts, [:user_id, :target_app],
              unique: true, algorithm: :concurrently,
              name: 'index_user_consent_sts_on_user_id_and_target_app'
  end
end
