# frozen_string_literal: true

# Whether a delegated token is bound to the service provider's key (RFC 9449) follows the service
# provider's client type alone: a public client's tokens are always bound, a confidential client's
# never. An agency API has no say in it, so the per-URL flag has no reader and goes.
class RemoveDpopRequiredFromTokenExchangeResourceServers < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :token_exchange_resource_servers, :dpop_required, :boolean,
                    null: false, default: false, comment: 'sensitive=false'
    end
  end
end
