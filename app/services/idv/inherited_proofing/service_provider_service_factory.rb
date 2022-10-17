module Idv
  module InheritedProofing
    module ServiceProviderServiceFactory
      class << self
        # Returns the service for the service provider
        def service(service_provider:, service_provider_data: {})
          Factory.new(
            service_provider: service_provider,
            service_provider_data: service_provider_data,
          ).inherited_proofing_service
        end

        def execute(service_provider:, service_provider_data: {})
          service(
            service_provider: service_provider,
            service_provider_data: service_provider_data,
          ).execute
        end
      end

      private

      class Factory
        include ServiceProviders
        include ServiceProviderServices

        attr_reader :service_provider, :service_provider_data

        def initialize(service_provider:, service_provider_data: {})
          @service_provider = service_provider
          @service_provider_data = service_provider_data
        end

        # ServiceProviderServices overrides

        def va_inherited_proofing?
          service_provider == VA
        end

        def inherited_proofing_service_provider_data
          service_provider_data
        end
      end
    end
  end
end
