module Idv
  module Steps
    class VerifyBaseStep < DocAuthBaseStep
      AAMVA_SUPPORTED_JURISDICTIONS = %w[
        AR AZ CO CT DC DE FL GA IA ID IL IN KY MA MD ME MI MO MS MT ND NE NJ NM
        PA RI SC SD TX VA VT WA WI WY
      ].freeze

      private

      def perform_resolution_and_check_ssn
        pii_from_doc = flow_session[:pii_from_doc]
        # do resolution first to prevent ssn time/discovery. resolution time order > than db call
        idv_result = perform_resolution(pii_from_doc)
        add_proofing_costs(idv_result)
        response = idv_result_to_form_response(idv_result)
        response = check_ssn(pii_from_doc) if response.success?
        summarize_result_and_throttle_failures(response)
      end

      def summarize_result_and_throttle_failures(summary_result)
        if summary_result.success?
          add_proofing_components
          summary_result
        else
          idv_failure(summary_result)
        end
      end

      def add_proofing_components
        Db::ProofingComponent::Add.call(user_id, :resolution_check, 'lexis_nexis')
        Db::ProofingComponent::Add.call(user_id, :source_check, 'aamva')
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
        Idv::Agent.new(pii_from_doc).proof_resolution(
          should_proof_state_id: should_use_aamva?(pii_from_doc),
        )
      end

      def idv_result_to_form_response(idv_result)
        FormResponse.new(
          success: idv_success(idv_result),
          errors: idv_errors(idv_result),
          extra: { proofing_results: idv_extra(idv_result) },
        )
      end

      def add_proofing_costs(results)
        vendors = results[:context][:stages]
        vendors.each do |hash|
          add_cost(:aamva) if hash[:state_id]
          add_cost(:lexis_nexis_resolution) if hash[:resolution]
        end
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

      def should_use_aamva?(pii_from_doc)
        aamva_state?(pii_from_doc) && !aamva_disallowed_for_service_provider?
      end

      def aamva_state?(pii_from_doc)
        AAMVA_SUPPORTED_JURISDICTIONS.include? pii_from_doc['state_id_jurisdiction']
      end

      def aamva_disallowed_for_service_provider?
        return false if sp_session.nil?
        banlist = JSON.parse(Figaro.env.aamva_sp_banlist_issuers || '[]')
        banlist.include?(sp_session[:issuer])
      end
    end
  end
end
