# frozen_string_literal: true

class UpdateUserConsentStsTargetAppComment < ActiveRecord::Migration[8.1]
  def up
    change_column_comment :user_consent_sts, :target_app,
                          'Issuer of the target SP the user consented to sensitive=false'
  end

  def down
    change_column_comment :user_consent_sts, :target_app,
                          'Issuer of the broker SP the user consented to sensitive=false'
  end
end
