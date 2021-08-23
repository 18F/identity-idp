class CreateProofingComponents < ActiveRecord::Migration[5.1]
  def change
    create_table :proofing_components do |t|
      t.integer  :user_id, null: false
      t.string  :document_check
      t.string  :document_type
      t.string  :source_check
      t.string  :resolution_check
      t.string  :address_check
      t.datetime :verified_at

      t.timestamps
    end
    add_index :proofing_components, %i[user_id], unique: true
    add_index :proofing_components, %i[verified_at]
  end
end
