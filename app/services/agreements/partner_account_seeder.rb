# frozen_string_literal: true

module Agreements
  class PartnerAccountSeeder < BaseSeeder
    # The core functionality of this class is defined in BaseSeeder

    private

    def record_class
      PartnerAccount
    end

    def filename
      'partner_accounts.yml'
    end

    def primary_attribute_bundle(config)
      { 'requesting_agency' => config['requesting_agency'] }
    end

    def process_config(requesting_agency, config)
      config['agency'] = Agency.find_by!(abbreviation: config['agency'])
      config['partner_account_status'] =
        PartnerAccountStatus.find_by!(name: config['partner_account_status'])

      permitted_attrs = %w[name agency partner_account_status crm_id became_partner]
      config.slice(*permitted_attrs).merge('requesting_agency' => requesting_agency)
    end
  end
end
