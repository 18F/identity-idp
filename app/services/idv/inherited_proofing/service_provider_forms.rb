module Idv
  module InheritedProofing
    module ServiceProviderForms
      def inherited_proofing_form_for(service_provider, payload_hash:)
        if service_provider == :va
          return Idv::InheritedProofing::Va::Form.new payload_hash: payload_hash
        end

        raise 'Inherited proofing form could not be identified'
      end
    end
  end
end
