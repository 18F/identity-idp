class CreateSecurityEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :security_events do |t|
      t.references :user, null: false
      t.string :event_type, null: false
      t.string :jti
      t.string :issuer
      t.timestamps
    end
    add_index :security_events, ["jti"], name: "index_security_events_on_jti"
  end
end
