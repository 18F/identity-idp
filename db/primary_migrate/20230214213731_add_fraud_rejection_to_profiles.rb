class AddFraudRejectionToProfiles < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :fraud_rejection, :boolean, default: false
  end
end
