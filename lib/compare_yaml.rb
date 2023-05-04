require 'pry'
require_relative '../app/services/service_provider_seeder'

class CompareYaml
    # This is a black box end-to-end test spitting out the results and checking for regressions trying to replicate as close as possible the production database
    # Before you can run this script you must have identity-idp-config repo set up and run serialized.rb script
    # Serialized.rb script will create a 'serialized' folder which needs to be copied to this repo
    # It will also create a config folder and all files inside should be copied into the identity-idp config folder replacubg the existing yml files which only have test data

    def initialize
        @diff = {
            service_providers: [],
            integrations: [],
            iaa_orders: [],
        }
    end

    def run
        serialized = run_serializer('serialized')
        reset_db
        production = run_serializer('config')
        # loop through serialized and find the matching provider in production 
        serialized[:service_providers].each do |key, value|
            add_to_diff(:service_providers, key, value, production)
        end
        serialized[:integrations].each do |key, value|
            add_to_diff(:integrations, key, value, production)
        end
        serialized[:iaa_orders].each do |key, value|
            add_to_diff(:iaa_orders, key, value, production)
        end
        @diff
    end

    # put the issuers with data that doesn't match in the diff hash
    def add_to_diff(symbol, key, value, production)
        prod = production[symbol][key]
        if prod.nil?
            @diff[symbol] << key
        else
            if value != prod
                @diff[symbol] << key
            end
        end
    end

    def run_serializer(path)
        ServiceProviderSeeder.new(rails_env: 'production', deploy_env: 'prod', yaml_path: path).run
        AgencySeeder.new(rails_env: 'production').run
        Agreements::PartnerAccountStatusSeeder.new(rails_env: 'production').run
        Agreements::PartnerAccountSeeder.new(rails_env: 'production').run
        Agreements::IaaGtcSeeder.new(rails_env: 'production').run
        Agreements::IntegrationStatusSeeder.new(rails_env: 'production').run
        Agreements::IntegrationSeeder.new(rails_env: 'production', yaml_path: path).run
        Agreements::IaaOrderSeeder.new(rails_env: 'production', yaml_path: path).run
        objects
    end

    # restructure objects for a hash with a top-level key 
    def objects
        {
            service_providers: ServiceProvider.all.each_with_object({}) do |sp, object|
                object[sp[:issuer].to_s] = sp.attributes.except( "id", "created_at", "updated_at") 
            end,
            integrations: Agreements::Integration.all.each_with_object({}) do |int, object|
                object[int[:issuer].to_s] = int.attributes.except("id")
            end,
            iaa_orders: Agreements::IaaOrder.all.each_with_object({}) do |order, object|
                object[order[:iaa_gtc_id].to_s] = order.attributes.except("id")
            end,
        }.with_indifferent_access
    end

    def reset_db
        Agreements::IntegrationUsage.destroy_all
        Agreements::IaaOrder.destroy_all
        Agreements::Integration.destroy_all
        Agreements::IntegrationStatus.destroy_all
        Agreements::IaaGtc.destroy_all
        Agreements::PartnerAccount.destroy_all
        Agreements::PartnerAccountStatus.destroy_all
        Agency.destroy_all
        ServiceProvider.destroy_all
    end
end