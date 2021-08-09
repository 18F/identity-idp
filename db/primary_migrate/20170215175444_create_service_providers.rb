class CreateServiceProviders < ActiveRecord::Migration[4.2]
  def change
    create_table :service_providers do |t|
      t.string   "issuer", null: false
      t.string   "friendly_name"
      t.text     "description"
      t.text     "metadata_url"
      t.text     "acs_url"
      t.text     "assertion_consumer_logout_service_url"
      t.text     "cert"
      t.text     "logo"
      t.string   "fingerprint"
      t.string   "signature"
      t.string   "block_encryption", default: 'aes256-cbc', null: false
      t.text     "sp_initiated_login_url"
      t.text     "return_to_sp_url"
      t.string   "agency"
      t.json     "attribute_bundle"
      t.string   "redirect_uri"

      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean  "active", default: false, null: false
      t.boolean  "approved", default: false, null: false
    end

    add_index :service_providers, ["issuer"], name: "index_service_providers_on_issuer", unique: true, using: :btree
  end
end
