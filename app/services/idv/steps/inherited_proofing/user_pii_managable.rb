module Idv
  module Steps
    module InheritedProofing
      module UserPiiManagable
        include UserPiiRetrievable

        def inherited_proofing_save_user_pii_to_session!
          inherited_proofing_save_session!
          inherited_proofing_skip_steps!
        end

        private

        def inherited_proofing_save_session!
          return unless inherited_proofing_form_response.success?

          flow_session[:pii_from_user] =
            flow_session[:pii_from_user].to_h.merge(inherited_proofing_user_pii)
        end

        def inherited_proofing_skip_steps!
          idv_session['profile_confirmation'] = true
          idv_session['vendor_phone_confirmation'] = false
          idv_session['user_phone_confirmation'] = false
          idv_session['address_verification_mechanism'] = 'phone'
          idv_session['resolution_successful'] = 'phone'
        end
      end
    end
  end
end
