# frozen_string_literal: true

module Idv
  module DocumentCaptureConcern
    extend ActiveSupport::Concern

    include DocAuthVendorConcern

    def save_proofing_components(user)
      return unless user

      component_attributes = {
        document_check: doc_auth_vendor,
        document_type: 'state_id',
      }
      ProofingComponent.create_or_find_by(user: user).update(component_attributes)
    end

    def successful_response
      FormResponse.new(success: true)
    end

    # copied from Flow::Failure module
    def failure(message, extra = nil)
      flash[:error] = message
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
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

    # @returns[String] The document capture path for the current vendor
    def doc_auth_vendor_capture_path(in_hybrid_mobile)
      case doc_auth_vendor
      when Idp::Constants::Vendors::SOCURE
        in_hybrid_mobile ? idv_hybrid_mobile_socure_document_capture_path
                         : idv_socure_document_capture_path
      when Idp::Constants::Vendors::LEXIS_NEXIS, Idp::Constants::Vendors::MOCK
        in_hybrid_mobile ? idv_hybrid_mobile_document_capture_path
                         : idv_document_capture_path
      end
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
