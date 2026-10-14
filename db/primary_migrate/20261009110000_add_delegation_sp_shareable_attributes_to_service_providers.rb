# frozen_string_literal: true

# The identity attributes an agency application chooses to share with the service provider that
# acts for a person at it. When the public-client service provider introspects its own delegated
# token, the response carries the token's status and the person's identifier as the service
# provider's own sign-in already reports it; this list is the only way any further attribute
# reaches it. Names come from the agency's attribute-bundle vocabulary (`first_name`, `email`,
# `address1`, ...), and an attribute is released only if the application's own bundle also
# contains it. Empty by default: an application shares nothing unless its agency decides to.
class AddDelegationSpShareableAttributesToServiceProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :service_providers, :delegation_sp_shareable_attributes, :string,
               array: true, default: [], null: false, comment: 'sensitive=false'
  end
end
