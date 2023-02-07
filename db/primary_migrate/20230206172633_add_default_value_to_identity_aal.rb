class AddDefaultValueToIdentityAal < ActiveRecord::Migration[7.0]
  def change
    change_column_default :identities, :aal, 0
  end
end
