# frozen_string_literal: true

module Agreements
  class IntegrationStatusSeeder < BaseSeeder
    # The core functionality of this class is defined in BaseSeeder

    private

    def record_class
      IntegrationStatus
    end

    def filename
      'integration_statuses.yml'
    end

    def primary_attribute_bundle(config)
      { 'name' => config['name'] }
    end

    def process_config(name, config)
      permitted_attrs = %w[order partner_name]
      config.slice(*permitted_attrs).merge('name' => name)
    end
  end
end
