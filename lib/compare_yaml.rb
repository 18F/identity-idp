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
        reset_db
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
        return serialized, production, @diff
    end

    # find the differences with issuer data that doesn't match in the diff hash
    def add_to_diff(symbol, key, value, production)
        prod = production[symbol][key]
        if prod.nil?
            @diff[symbol] << Hash[key, "does not exist in prod"]
        else
            if value != prod
                #to handle iaa_orders being grouped by partner_account_name (more than one order per account) 
                if symbol == :iaa_orders && value.length > 1
                    handle_account_with_multiple_orders(value, prod, symbol)
                else 
                    @diff[symbol] << Hash[key, value.to_a - prod.to_a]
                end
            end
        end
    end

    def handle_account_with_multiple_orders(value, prod, symbol)
        value.each_with_index do |item, index|
            if(prod[index] != item)
               account_name_hash = @diff[symbol].find {|h| !h[item["partner_account_name"]].nil?}
                if account_name_hash.nil?
                    @diff[symbol] << Hash[item["partner_account_name"], [item.to_a - prod[index].to_a]]
                else 
                    account_name_hash[item["partner_account_name"]] << item.to_a - prod[index].to_a
                end
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
                object[sp[:issuer].to_s] = sp.attributes.except( "id", "created_at", "updated_at", "irs_attempts_api_enabled") 
            end,
            integrations: Agreements::Integration.all.each_with_object({}) do |int, object|
                object[int[:issuer].to_s] = int.attributes.except("id", "partner_account_id", "integration_status_id", "service_provider_id")
            end,
            iaa_orders: Agreements::IaaOrder.all.includes(:partner_account).each_with_object({}) do |order, object|
                #this is necessary because id values are randomly generated and do not match across the two instances
                partner_name = Hash['partner_account_name', order.partner_account.name]
                if !object[order.partner_account.name]
                    object[order.partner_account.name] = []
                end
                object[order.partner_account.name] << order.attributes.except("id", "iaa_gtc_id").merge(partner_name)
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