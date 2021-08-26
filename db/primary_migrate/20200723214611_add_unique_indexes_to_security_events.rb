class AddUniqueIndexesToSecurityEvents < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :security_events, ["jti", "user_id", "issuer"], name: "index_security_events_on_jti_and_user_id_and_issuer", unique: true, algorithm: :concurrently

    # created in past PR, now redundant
    remove_index :security_events, name: "index_security_events_on_jti", column: ["jti"]
  end
end
