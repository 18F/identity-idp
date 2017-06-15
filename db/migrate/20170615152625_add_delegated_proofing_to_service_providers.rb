class AddDelegatedProofingToServiceProviders < ActiveRecord::Migration
  def change
    add_column :service_providers, :supports_delegated_proofing, :boolean, default: false
  end
end
