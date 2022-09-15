class AddInPersonProofingEnabledToServiceProvider < ActiveRecord::Migration[7.0]
  def change
    add_column :service_providers, :in_person_proofing_enabled, :boolean, default: false
  end
end
