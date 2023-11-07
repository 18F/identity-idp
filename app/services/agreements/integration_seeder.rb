module Agreements
  class IntegrationSeeder < BaseSeeder
    # The core functionality of this class is defined in BaseSeeder

    private

    def record_class
      Integration
    end

    def filename
      'integrations.yml'
    end

    def primary_attribute_bundle(config)
      { 'issuer' => config['issuer'] }
    end

    def process_config(issuer, config)
      config['partner_account'] =
        PartnerAccount.find_by!(requesting_agency: config['partner_account'])
      config['integration_status'] =
        IntegrationStatus.find_by!(name: config['integration_status'])
      config['service_provider'] = ServiceProvider.find_by!(issuer:)

      permitted_attrs =
        %w[name dashboard_identifier service_provider integration_status partner_account]
      config.slice(*permitted_attrs).merge('issuer' => issuer)
    end
  end
end
