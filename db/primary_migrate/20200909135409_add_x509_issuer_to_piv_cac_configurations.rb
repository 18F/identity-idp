class AddX509IssuerToPivCacConfigurations < ActiveRecord::Migration[5.1]
  def change
    add_column :piv_cac_configurations, :x509_issuer, :string
  end
end
