# frozen_string_literal: true

class ValidateUserConsentStsActorAppNotNull < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :user_consent_sts, name: 'user_consent_sts_actor_app_null'
    change_column_null :user_consent_sts, :actor_app, false
    remove_check_constraint :user_consent_sts, name: 'user_consent_sts_actor_app_null'
  end

  def down
    add_check_constraint :user_consent_sts, 'actor_app IS NOT NULL',
                         name: 'user_consent_sts_actor_app_null', validate: false
    change_column_null :user_consent_sts, :actor_app, true
  end
end
