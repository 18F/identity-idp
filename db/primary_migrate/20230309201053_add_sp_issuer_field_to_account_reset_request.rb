class AddSpIssuerFieldToAccountResetRequest < ActiveRecord::Migration[7.0]
  def change
    add_column :account_reset_requests, :requesting_issuer, :string
  end
end
