module Agreements
  class IaaStatusSeeder < BaseSeeder
    # The core functionality of this class is defined in BaseSeeder

    private

    def record_class
      IaaStatus
    end

    def filename
      'iaa_statuses.yml'
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
