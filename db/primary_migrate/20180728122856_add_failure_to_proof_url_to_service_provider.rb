class AddFailureToProofUrlToServiceProvider < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :failure_to_proof_url, :text
  end

  def down
    remove_column :service_providers, :failure_to_proof_url
  end
end
