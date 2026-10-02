# frozen_string_literal: true

class AddAllowedTokenExchangeBrokersToServiceProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :service_providers, :allowed_token_exchange_brokers, :string,
               array: true, default: [], comment: 'sensitive=false'
  end
end
