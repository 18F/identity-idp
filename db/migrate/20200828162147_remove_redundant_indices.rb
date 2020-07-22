class RemoveRedundantIndices < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    remove_index :email_addresses, name: "index_email_addresses_on_all_email_fingerprints", algorithm: :concurrently
    remove_index :identities, name: "index_identities_on_user_id", algorithm: :concurrently
    remove_index :job_runs, name: "index_job_runs_on_job_name", algorithm: :concurrently
    remove_index :phone_configurations, name: "index_phone_configurations_on_user_id", algorithm: :concurrently
  end
end
