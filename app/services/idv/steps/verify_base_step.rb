module Idv
  module Steps
    class VerifyBaseStep < DocAuthBaseStep
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
        ProofingComponent.create_or_find_by(user: current_user).update(
          resolution_check: 'lexis_nexis',
          source_check: 'aamva',
        )
      end

      def check_ssn
        result = Idv::SsnForm.new(current_user).submit(ssn: pii[:ssn])

        if result.success?
          save_legacy_state
          delete_pii
        end

        result
      end

      def save_legacy_state
        skip_legacy_steps
        idv_session['applicant'] = pii
        idv_session['applicant']['uuid'] = current_user.uuid
      end

      def skip_legacy_steps
        idv_session['profile_confirmation'] = true
        idv_session['vendor_phone_confirmation'] = false
        idv_session['user_phone_confirmation'] = false
        idv_session['address_verification_mechanism'] = 'phone'
        idv_session['resolution_successful'] = 'phone'
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

      def pii
        flow_session[:pii_from_doc].presence || flow_session[:pii_from_user]
      end

      def delete_pii
        flow_session.delete(:pii_from_doc)
        flow_session.delete(:pii_from_user)
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
        IdentityConfig.store.aamva_supported_jurisdictions.include?(
          pii_from_doc['state_id_jurisdiction'],
        )
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
