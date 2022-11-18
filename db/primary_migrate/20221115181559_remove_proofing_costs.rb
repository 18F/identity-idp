class RemoveProofingCosts < ActiveRecord::Migration[7.0]
  def change
    drop_table "proofing_costs" do |t|
      t.integer "user_id", null: false
      t.integer "acuant_front_image_count", default: 0
      t.integer "acuant_back_image_count", default: 0
      t.integer "aamva_count", default: 0
      t.integer "lexis_nexis_resolution_count", default: 0
      t.integer "lexis_nexis_address_count", default: 0
      t.integer "gpo_letter_count", default: 0
      t.integer "phone_otp_count", default: 0
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
      t.integer "acuant_result_count", default: 0
      t.integer "acuant_selfie_count", default: 0
      t.integer "threatmetrix_count", default: 0
      t.index ["user_id"], name: "index_proofing_costs_on_user_id", unique: true
    end
  end
end
