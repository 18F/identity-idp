module Idv
  module Steps
    class SsnStep < DocAuthBaseStep
      def call
        pii_from_doc = flow_session[:pii_from_doc]
        pii_from_doc[:ssn] = flow_params[:ssn]
        result = perform_resolution(pii_from_doc)
        if result.success?
          step_successful(pii_from_doc)
        else
          flow_session[:matcher_pii_from_doc] = pii_from_doc
        end
      end

      private

      def form_submit
        Idv::SsnForm.new(current_user).submit(permit(:ssn))
      end

      def step_successful(pii_from_doc)
        mark_step_complete(:doc_failed) # skip doc failed
        save_legacy_state(pii_from_doc)
      end

      def save_legacy_state(pii_from_doc)
        skip_legacy_steps
        idv_session['params'] = pii_from_doc
        idv_session['applicant'] = pii_from_doc
        idv_session['applicant']['uuid'] = current_user.uuid
      end

      def skip_legacy_steps
        idv_session['profile_confirmation'] = true
        idv_session['vendor_phone_confirmation'] = true
        idv_session['user_phone_confirmation'] = true
        idv_session['address_verification_mechanism'] = 'phone'
        idv_session['resolution_successful'] = 'phone'
      end

      def perform_resolution(pii_from_doc)
        idv_result = Idv::Agent.new(pii_from_doc).proof(:resolution)
        FormResponse.new(
          success: idv_result[:success], errors: idv_result[:errors]
        )
      end
    end
  end
end
