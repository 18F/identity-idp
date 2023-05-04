require 'pry'
require_relative '../app/services/service_provider_seeder'

class CompareYaml
    # before you can run this script you must have identity-idp-config repo set up and run serialized.rb script
    # serialized.rb script will create a 'serialized' folder which needs to be copied to this repo
    # it will also create a config folder and all files inside should be copied into the identity-idp config folder and replace matching existing yml files


    def run
        serialized = run_serializer('serialized')
        reset_db
        production = run_serializer('config')
        # black box end-to-end test spitting out the results and checking for regressions
        # trying to replicate as close as possible the production database
        # 1. restructure objects so that it is a hash with each issuer being the top-level key 
        # 2. loop through serialized and find the matching provider in production 
        # 3. compare them 
        # 4. if there are no differences, go on to the next one 
        # 5. if there are differences, put the issuer in an array that we can track
        diff = {
            service_providers: []
            integrations: []
            orders: []
        }
        serialized[:service_providers].each do |key, value|
            prod = production[:service_providers][key]
            if prod.nil?
                diff[:service_providers] << key
            else
                if value != prod
                    diff[:service_provider] << key
                end
            end 
        end
        serialized[:integrations].each do |key, value|
            prod = production[:integrations][key]
            if prod.nil?
                diff[:integrations] << key
            else
                if value != prod
                    diff[:integrations] << key
                end
            end
        end
        serialized[:iaa_orders].each do |key, value|
            prod = production[:iaa_orders][key]
            if prod.nil?
                diff[:orders] << key
            else
                if value != prod
                    diff[:orders] << key
                end
            end
        end
    end

    def run_serializer(path)
        # seeder depends on data validations to work
        # idp seeder is not what changed but the yaml files so are we sure we need to use the seeders in identity-idp? 
        # if there is a way to just test within identity-idp-config instead it might be worth looking into?
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