# frozen_string_literal: true

class AddRecoveryCodeToSiteKeyRoots < ActiveRecord::Migration[8.1]
  def change
    change_column_null :site_key_roots, :encrypted_root, true
    add_column :site_key_roots, :encrypted_root_recovery_code, :text, comment: 'sensitive=true'
    add_column :site_key_roots, :recovery_code_generated_at, :datetime, comment: 'sensitive=false'
    add_column :site_key_roots, :recovery_code_acknowledged_at, :datetime,
               comment: 'sensitive=false'
  end
end
