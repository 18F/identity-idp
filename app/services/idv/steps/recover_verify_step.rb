module Idv
  module Steps
    class RecoverVerifyStep < VerifyBaseStep
      def call
        perform_resolution_and_check_ssn
      end

      private

      def idv_failure(result)
        attempter_increment if result.extra.dig(:proofing_results, :exception).present?
        if attempter_throttled?
          redirect_to idv_session_errors_recovery_failure_url
        elsif result.extra.dig(:proofing_results, :exception).present?
          redirect_to idv_session_errors_recovery_exception_url
        else
          redirect_to idv_session_errors_recovery_warning_url
        end
        result
      end

      def summarize_result_and_throttle_failures(summary_result)
        if summary_result.success? && doc_auth_pii_matches_decrypted_pii
          add_proofing_components
          summary_result
        else
          idv_failure(summary_result)
        end
      end

      def doc_auth_pii_matches_decrypted_pii
        pii_from_doc = session['idv/recovery']['pii_from_doc']
        decrypted_pii = JSON.parse(saved_pii)
        return unless pii_matches_data_on_file?(pii_from_doc, decrypted_pii)

        recovery_success
      end

      def recovery_success
        flash[:success] = I18n.t('recover.reverify.success')
        redirect_to account_url
        session['need_two_factor_authentication'] = false
        true
      end

      def saved_pii
        session['decrypted_pii']
      end

      def pii_matches_data_on_file?(pii_from_doc, decrypted_pii)
        %w[first_name last_name dob ssn].each do |key|
          return false unless pii_from_doc[key] == decrypted_pii[key]
        end
        true
      end
    end
  end
end
