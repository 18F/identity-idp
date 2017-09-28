class AddNonceToIdentities < ActiveRecord::Migration[4.2]
  def change
    # from OpenID Connect authorizations
    add_column :identities, :nonce, :string
  end
end
