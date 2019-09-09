class CreateProofingCosts < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    create_table :proofing_costs do |t|
      t.integer  :user_id, null: false
      t.integer  :acuant_front_image_count, default: 0
      t.integer  :acuant_back_image_count, default: 0
      t.integer  :aamva_count, default: 0
      t.integer  :lexis_nexis_resolution_count, default: 0
      t.integer  :lexis_nexis_address_count, default: 0
      t.integer  :gpo_letter_count, default: 0
    end
    add_index :proofing_costs, %i[user_id], algorithm: :concurrently, unique: true
  end
end
