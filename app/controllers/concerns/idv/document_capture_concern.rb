# frozen_string_literal: true

module Idv
  module DocumentCaptureConcern
    extend ActiveSupport::Concern

    include DocAuthVendorConcern

    def handle_stored_result(user: current_user, store_in_session: true)
      if stored_result&.success? && selfie_requirement_met?
        extract_pii_from_doc(user, store_in_session: store_in_session)
        flash[:success] = t('doc_auth.headings.capture_complete')
        successful_response
      else
        extra = { stored_result_present: stored_result.present? }
        failure(nil, extra)
      end
    end

    def successful_response
      FormResponse.new(success: true)
    end

    # copied from Flow::Failure module
    def failure(message = nil, extra = nil)
      form_response_params = { success: false }
      form_response_params[:errors] = make_error_hash(message)
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end

    def make_error_hash(message)
      Rails.logger.info("make_error_hash: stored_result: #{stored_result.inspect}")

      error_hash = { message: message || I18n.t('doc_auth.errors.general.network_error') }

      if stored_result&.errors&.has_key?(:socure)
        error_hash[:socure] = stored_result.errors[:socure]
      end

      error_hash
    end

    def extract_pii_from_doc(user, store_in_session: false)
      if defined?(idv_session) # hybrid mobile does not have idv_session
        idv_session.had_barcode_read_failure = stored_result.attention_with_barcode?
        if store_in_session
          idv_session.pii_from_doc = stored_result.pii_from_doc
          idv_session.selfie_check_performed = stored_result.selfie_check_performed?
        end
      end

      track_document_issuing_state(user, stored_result.pii_from_doc[:state])
    end

    def stored_result
      return @stored_result if defined?(@stored_result)
      @stored_result = document_capture_session&.load_result
    end

    def selfie_requirement_met?
      !resolved_authn_context_result.facial_match? ||
        stored_result.selfie_check_performed?
    end

    def redirect_to_correct_vendor(vendor, in_hybrid_mobile)
      expected_doc_auth_vendor = doc_auth_vendor
      return if vendor == expected_doc_auth_vendor
      return if vendor == Idp::Constants::Vendors::LEXIS_NEXIS &&
                expected_doc_auth_vendor == Idp::Constants::Vendors::MOCK

      correct_path = case expected_doc_auth_vendor
        when Idp::Constants::Vendors::SOCURE
          in_hybrid_mobile ? idv_hybrid_mobile_socure_document_capture_path
                           : idv_socure_document_capture_path
        when Idp::Constants::Vendors::LEXIS_NEXIS, Idp::Constants::Vendors::MOCK
          in_hybrid_mobile ? idv_hybrid_mobile_document_capture_path
                           : idv_document_capture_path
        end

      redirect_to correct_path
    end

    def fetch_test_verification_data
      if IdentityConfig.store.socure_docv_verification_data_test_mode
        docv_transaction_token_override = params.permit(:docv_token)[:docv_token]
        if IdentityConfig.store.socure_docv_verification_data_test_mode_tokens.
            include?(docv_transaction_token_override)
          SocureDocvResultsJob.perform_now(
            document_capture_session_uuid:,
            docv_transaction_token_override:,
            async: true,
          )
        end
      end
    end

    private

    def track_document_issuing_state(user, state)
      return unless IdentityConfig.store.state_tracking_enabled && state
      doc_auth_log = DocAuthLog.find_by(user_id: user.id)
      return unless doc_auth_log
      doc_auth_log.state = state
      doc_auth_log.save!
    end
  end
end
