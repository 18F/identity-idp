class CleanupIdentitiesTable < ActiveRecord::Migration
  def change
    remove_column :identities, :ial
    remove_column :identities, :authn_context
    add_index 'identities', ['user_id', 'service_provider']
  end
end
