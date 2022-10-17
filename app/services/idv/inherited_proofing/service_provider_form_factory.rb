module Idv
  module InheritedProofing
    module ServiceProviderFormFactory
      class << self
        # Returns the form for the service provider
        def form(service_provider:, payload_hash:)
          Factory.new(service_provider: service_provider, payload_hash: payload_hash).form
        end
      end

      private

      class Factory
        include ServiceProviders
        include ServiceProviderForms

        attr_reader :service_provider, :payload_hash

        def initialize(service_provider:, payload_hash:)
          @service_provider = service_provider
          @payload_hash = payload_hash
        end

        def form
          inherited_proofing_form(payload_hash)
        end

        def va_inherited_proofing?
          service_provider == VA
        end
      end
    end
  end
end
