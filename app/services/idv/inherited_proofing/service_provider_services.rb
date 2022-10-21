module Idv
  module InheritedProofing
    module ServiceProviderServices
      def inherited_proofing_service_for(service_provider, service_provider_data:)
        inherited_proofing_service_class_for(service_provider).new(service_provider_data)
      end

      def inherited_proofing_service_class_for(service_provider)
        unless IdentityConfig.store.inherited_proofing_enabled
          raise 'Inherited Proofing is not enabled'
        end

        if service_provider == :va
          if IdentityConfig.store.va_inherited_proofing_mock_enabled
            return Idv::InheritedProofing::Va::Mocks::Service
          end
          return Idv::InheritedProofing::Va::Service
        end

        raise 'Inherited proofing service class could not be identified'
      end
    end
  end
end
