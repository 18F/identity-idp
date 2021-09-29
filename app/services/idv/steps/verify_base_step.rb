module Idv
  module Steps
    class VerifyBaseStep < DocAuthBaseStep
      AAMVA_SUPPORTED_JURISDICTIONS = %w[
        AR AZ CO CT DC DE FL GA IA ID IL IN KY MA MD ME MI MO MS MT ND NE NJ NM
        PA RI SC SD TX VA VT WA WI WY
      ].to_set.freeze

      private

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

      def idv_result_to_form_response(idv_result:, state: nil, extra: {})
        state_id = idv_result.dig(:context, :stages, :state_id)
        state_id[:state] = state if state && state_id
        FormResponse.new(
          success: idv_success(idv_result),
          errors: idv_errors(idv_result),
          extra: extra.merge(proofing_results: idv_extra(idv_result)),
        )
      end

      def add_proofing_costs(results)
        results[:context][:stages].each do |stage, hash|
          if stage == :resolution
            # transaction_id comes from ConversationId
            add_cost(:lexis_nexis_resolution, transaction_id: hash[:transaction_id])
          elsif stage == :state_id
            process_aamva(hash[:transaction_id])
          end
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
        AAMVA_SUPPORTED_JURISDICTIONS.include?(pii_from_doc['state_id_jurisdiction'])
      end

      def aamva_disallowed_for_service_provider?
        return false if sp_session.nil?
        banlist = IdentityConfig.store.aamva_sp_banlist_issuers
        banlist.include?(sp_session[:issuer])
      end

      def process_aamva(transaction_id)
        # transaction_id comes from TransactionLocatorId
        add_cost(:aamva, transaction_id: transaction_id)
        track_aamva
      end

      def track_aamva
        return unless IdentityConfig.store.state_tracking_enabled
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return unless doc_auth_log
        doc_auth_log.aamva = true
        doc_auth_log.save!
      end
    end
  end
end
