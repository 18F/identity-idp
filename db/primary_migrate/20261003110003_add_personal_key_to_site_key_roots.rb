# frozen_string_literal: true

class AddPersonalKeyToSiteKeyRoots < ActiveRecord::Migration[8.1]
  def change
    add_column :site_key_roots, :encrypted_root_personal_key, :text, comment: 'sensitive=true'
  end
end
