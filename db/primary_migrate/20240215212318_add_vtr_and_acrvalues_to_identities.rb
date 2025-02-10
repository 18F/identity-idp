class AddVtrAndAcrvaluesToIdentities < ActiveRecord::Migration[7.1]
  def change
    add_column :identities, :vtr, :string
    add_column :identities, :acr_values, :string
  end
end
