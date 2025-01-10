class DropProofingComponentsTable < ActiveRecord::Migration[7.2]
  def change
    drop_table :proofing_components do |t|
      t.integer "user_id", null: false, comment: "sensitive=false"
      t.string "document_check", comment: "sensitive=false"
      t.string "document_type", comment: "sensitive=false"
      t.string "source_check", comment: "sensitive=false"
      t.string "resolution_check", comment: "sensitive=false"
      t.string "address_check", comment: "sensitive=false"
      t.datetime "verified_at", precision: nil, comment: "sensitive=false"
      t.datetime "created_at", precision: nil, null: false, comment: "sensitive=false"
      t.datetime "updated_at", precision: nil, null: false, comment: "sensitive=false"
      t.string "liveness_check", comment: "sensitive=false"
      t.string "device_fingerprinting_vendor", comment: "sensitive=false"
      t.boolean "threatmetrix", comment: "sensitive=false"
      t.string "threatmetrix_review_status", comment: "sensitive=false"
      t.string "threatmetrix_risk_rating", comment: "sensitive=false"
      t.string "threatmetrix_policy_score", comment: "sensitive=false"
      t.index ["user_id"], name: "index_proofing_components_on_user_id", unique: true
      t.index ["verified_at"], name: "index_proofing_components_on_verified_at"
    end
  end
end
