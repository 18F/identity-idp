class AddIssuerToProfile < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :initiating_issuer, :string, null: true
  end
end
