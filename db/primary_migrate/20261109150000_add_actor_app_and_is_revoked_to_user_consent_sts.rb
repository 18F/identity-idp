# frozen_string_literal: true

class AddActorAppAndIsRevokedToUserConsentSts < ActiveRecord::Migration[8.1]
  def change
    add_column :user_consent_sts, :actor_app, :string,
               comment: 'Actor the user consented to sensitive=false'
    add_column :user_consent_sts, :is_revoked, :boolean,
               null: false, default: false,
               comment: 'Whether the user revoked consent sensitive=false'

    add_check_constraint :user_consent_sts, 'actor_app IS NOT NULL',
                         name: 'user_consent_sts_actor_app_null', validate: false
  end
end
