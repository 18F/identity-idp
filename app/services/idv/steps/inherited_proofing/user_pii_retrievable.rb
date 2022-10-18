module Idv
  module Steps
    module InheritedProofing
      module UserPiiRetrievable
        def inherited_proofing_user_pii
          inherited_proofing_info[0]
        end

        def inherited_proofing_form_response
          inherited_proofing_info[1]
        end

        private

        # This needs error handling.
        def inherited_proofing_info
          return @inherited_proofing_info if defined? @inherited_proofing_info

          payload_hash = inherited_proofing_service.execute.dup
          form = inherited_proofing_form(payload_hash)
          form_response = form.submit

          user_pii = {}
          user_pii = form.user_pii if form_response.success?

          @inherited_proofing_info = [user_pii, form_response]
        end

        def inherited_proofing_service
          controller.inherited_proofing_service
        end

        def inherited_proofing_form(payload_hash)
          controller.inherited_proofing_form payload_hash
        end
      end
    end
  end
end
