# frozen_string_literal: true

# Whether a delegated token is bound to the service provider's key (RFC 9449) is a setting of the
# service provider that holds it, never of the API that receives it: only a public client can be
# bound, and the service provider's own record says whether it is. An agency API has no say in it,
# so the per-URL flag has no reader and goes.
class RemoveDpopRequiredFromTokenExchangeResourceServers < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :token_exchange_resource_servers, :dpop_required, :boolean,
                    null: false, default: false, comment: 'sensitive=false'
    end
  end
end
