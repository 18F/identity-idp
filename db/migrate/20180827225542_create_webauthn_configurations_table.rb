class CreateWebauthnConfigurationsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :webauthn_configurations do |t|
      t.references :user, null: false
      t.string :name, null: false
      t.text :credential_id, null: false
      t.text :credential_public_key, null: false
      t.timestamps

      t.index ['user_id'], name: "index_webauthn_configurations_on_user_id"
    end
  end
end
