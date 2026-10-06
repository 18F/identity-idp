# frozen_string_literal: true

class CreateSiteKeyRoots < ActiveRecord::Migration[8.1]
  def change
    create_table :site_key_roots do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true },
                   comment: 'sensitive=false'
      t.text :encrypted_root, null: false, comment: 'sensitive=true'
      t.timestamps comment: 'sensitive=false'
    end
  end
end
