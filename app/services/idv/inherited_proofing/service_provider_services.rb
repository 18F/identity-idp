module Idv
  module InheritedProofing
    module ServiceProviderServices
      include Idv::InheritedProofing::ServiceProviders

      # Not sure I like the naming here because it might imply the ServiceProvider#id.
      # However, we're using it here as the Inherited Proofing-specific Service
      # Provider (SP) identification, because we're currently identifying the SP
      # identify (in the case of the VA anyhow) by what is in Session.
      def inherited_proofing_service_provider_id
        return VA if va_inherited_proofing?

        raise 'Inherited proofing service id could not be identified'
      end

      def inherited_proofing_service
        inherited_proofing_service_class.new inherited_proofing_service_provider_data
      end

      def inherited_proofing_service_class
        unless IdentityConfig.store.inherited_proofing_enabled
          raise 'Inherited Proofing is not enabled'
        end

        if va_inherited_proofing?
          if IdentityConfig.store.va_inherited_proofing_mock_enabled
            return Idv::InheritedProofing::Va::Mocks::Service
          end
          return Idv::InheritedProofing::Va::Service
        end

        raise 'Inherited proofing service class could not be identified'
      end

      def inherited_proofing_service_provider_data
        if va_inherited_proofing?
          { auth_code: va_inherited_proofing_auth_code }
        else
          {}
        end
      end
    end
  end
end
