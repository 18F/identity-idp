class CreateDocAuths < ActiveRecord::Migration[5.1]
  def change
    create_table :doc_auths do |t|
      t.references :user, null: false
      t.datetime :attempted_at
      t.integer :attempts, default: 0
      t.datetime :license_confirmed_at
      t.datetime :selfie_confirmed_at
      t.timestamps
    end
  end
end
