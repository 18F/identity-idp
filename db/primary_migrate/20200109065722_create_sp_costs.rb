class CreateSpCosts < ActiveRecord::Migration[5.1]
  def change
    create_table :sp_costs do |t|
      t.string   :issuer, null: false
      t.integer  :agency_id, null: false
      t.string   :cost_type, null: false
      t.timestamps
    end
    add_index :sp_costs, %i[created_at]
  end
end
