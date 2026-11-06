# frozen_string_literal: true

class AddRecoveryCodeToSiteKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :site_keys, :encrypted_private_key_recovery_code, :text, comment: 'sensitive=true'
    add_column :site_keys, :recovery_code_generated_at, :datetime, comment: 'sensitive=false'
    add_column :site_keys, :recovery_code_acknowledged_at, :datetime, comment: 'sensitive=false'
  end
end
