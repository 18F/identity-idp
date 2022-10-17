module Idv
  module InheritedProofing
    module ServiceProviderForms
      def inherited_proofing_form(payload_hash)
        if va_inherited_proofing?
          return Idv::InheritedProofing::Va::Form.new payload_hash: payload_hash
          end

        raise 'Inherited proofing form could not be identified'
      end
      end
    end
  end
