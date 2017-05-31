class AddRailsSessionIdToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :rails_session_id, :string
  end
end
