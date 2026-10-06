# frozen_string_literal: true

class AddSiteKeyAllowedToServiceProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :service_providers, :site_key_allowed, :boolean, default: false, null: false,
                                                                comment: 'sensitive=false'
  end
end
