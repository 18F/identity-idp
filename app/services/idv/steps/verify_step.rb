module Idv
  module Steps
    class VerifyStep < DocAuthBaseStep
      def call
        pii_from_doc = flow_session[:pii_from_doc]
        # do resolution first to prevent ssn time/discovery. resolution time order > than db call
        result = perform_resolution(pii_from_doc)
        result = check_ssn(pii_from_doc) if result.success?
        summarize_result_and_throttle_failures(result)
      end

      private

      def summarize_result_and_throttle_failures(summary_result)
        summary_result.success? ? summary_result : idv_failure(summary_result)
      end

      def check_ssn(pii_from_doc)
        result = Idv::SsnForm.new(current_user).submit(ssn: pii_from_doc[:ssn])
        save_legacy_state(pii_from_doc) if result.success?
        result
      end

      def save_legacy_state(pii_from_doc)
        skip_legacy_steps
        idv_session['params'] = pii_from_doc
        idv_session['applicant'] = pii_from_doc
        idv_session['applicant']['uuid'] = current_user.uuid
      end

      def skip_legacy_steps
        idv_session['profile_confirmation'] = true
        idv_session['vendor_phone_confirmation'] = false
        idv_session['user_phone_confirmation'] = false
        idv_session['address_verification_mechanism'] = 'phone'
        idv_session['resolution_successful'] = 'phone'
      end

      def perform_resolution(pii_from_doc)
        stages = aamva_state?(pii_from_doc) ? [:resolution, :state_id] : [:resolution]
        idv_result = Idv::Agent.new(pii_from_doc).proof(*stages)
        FormResponse.new(
          success: idv_success(idv_result),
          errors: idv_errors(idv_result),
          extra: { proofing_results: idv_extra(idv_result) },
        )
      end

      def idv_success(idv_result)
        idv_result[:success]
      end

      def idv_errors(idv_result)
        idv_result[:errors]
      end

      def idv_extra(idv_result)
        idv_result.except(:errors, :success)
      end

      def aamva_state?(pii_from_doc)
        Idv::FormJurisdictionValidator::SUPPORTED_JURISDICTIONS.
          include? pii_from_doc['state_id_jurisdiction']
      end
    end
  end
end
