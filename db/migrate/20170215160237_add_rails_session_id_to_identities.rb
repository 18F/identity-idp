class AddRailsSessionIdToIdentities < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :rails_session_id, :string
  end
end
