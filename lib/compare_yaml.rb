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
        # each_with_object 
        # 1. restructure objects so that it is a hash with each issuer being the top-level key 
        # 2. loop through serialized and find the matching provider in production 
        # 3. compare them 
        # 4. if there are no differences, go on to the next one 
        # 5. if there are differences, put the issuer in an array that was can track

        
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

    def objects
        #this would work except that it can't always find an integration with an issuer that matches?? 
        # error: 'no method attributes' 
        sp = ServiceProvider.all.each_with_object({}) do |hash, item|
            binding.pry
            item[hash[:issuer].to_sym] = {
                service_provider: hash.attributes.except("issuer", "id", "created_at", "updated_at"),
                integration: Agreements::Integration.find_by(issuer: hash[:issuer].to_s).attributes.except("issuer"),
            }
        end
        {
            service_provider: sp,
            iaa_orders: Agreements::IaaOrder.all,
        }
    
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