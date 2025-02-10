class AddIdentitiesRequestedAalValue < ActiveRecord::Migration[7.0]
  def change
    add_column :identities, :requested_aal_value, :text
  end
end
