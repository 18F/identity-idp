class AddNonceToIdentities < ActiveRecord::Migration
  def change
    # from OpenID Connect authorizations
    add_column :identities, :nonce, :string
  end
end
