class AddCodeExpiresAtToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :code_expires_at, :datetime,
               comment: 'sensitive=false'
  end
end
