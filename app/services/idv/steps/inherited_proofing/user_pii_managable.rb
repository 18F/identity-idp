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

          mark_step_complete(:verify_wait)

          flow_session[:pii_from_user] =
            flow_session[:pii_from_user].to_h.merge(inherited_proofing_user_pii)
          # This is unnecessary, but added for completeness. Any subsequent FLOWS we
          # might splice into will pull from idv_session['applicant'] and merge into
          # flow_session[:pii_from_user] anyhow in their #initialize(r); any subsequent
          # STEP FLOWS we might splice into will populate idv_session['applicant'] and
          # ultimately get merged in to flow_session[:pii_from_user] as well.
          idv_session['applicant'] = flow_session[:pii_from_user]
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
