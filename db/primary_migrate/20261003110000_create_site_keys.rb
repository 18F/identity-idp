# frozen_string_literal: true

class CreateSiteKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :site_keys do |t|
      t.references :user, null: false, comment: 'sensitive=false',
                          foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.text :public_key, null: false, comment: 'sensitive=false'
      t.text :encrypted_private_key, comment: 'sensitive=true'
      t.timestamps comment: 'sensitive=false'
    end
  end
end
