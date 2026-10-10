# frozen_string_literal: true

# A service provider opts in to encrypted userinfo responses (OpenID Connect Core 1.0 §5.3.2) by
# naming the key-management algorithm; nil keeps the plain JSON response.
class AddUserinfoEncryptedResponseAlgToServiceProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :service_providers, :userinfo_encrypted_response_alg, :string,
               comment: 'sensitive=false'
  end
end
