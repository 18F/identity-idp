module Idv
  module DocumentCaptureConcern
    extend ActiveSupport::Concern

    private

    def save_proofing_components
      return unless effective_user

      doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
        discriminator: document_capture_session_uuid,
        analytics: analytics,
      )

      component_attributes = {
        document_check: doc_auth_vendor,
        document_type: 'state_id',
      }
      ProofingComponent.create_or_find_by(user: effective_user).update(component_attributes)
    end

    def track_document_state(state)
      return unless IdentityConfig.store.state_tracking_enabled && state
      doc_auth_log = DocAuthLog.find_by(user_id: effective_user.id)
      return unless doc_auth_log
      doc_auth_log.state = state
      doc_auth_log.save!
    end

    def successful_response
      FormResponse.new(success: true)
    end

    # copied from Flow::Failure module
    def failure(message, extra = nil)
      flow_session[:error_message] = message if defined?(flow_session)
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end

    # @param [DocAuth::Response,
    #   DocumentCaptureSessionAsyncResult,
    #   DocumentCaptureSessionResult] response
    def extract_pii_from_doc(response, store_in_session: false)
      pii_from_doc = response.pii_from_doc.merge(
        uuid: effective_user.uuid,
        phone: effective_user.phone_configurations.take&.phone,
        uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id,
      )

      if defined?(flow_session) # hybrid mobile does not have flow_session
        flow_session[:had_barcode_read_failure] = response.attention_with_barcode?
        if store_in_session
          flow_session[:pii_from_doc] ||= {}
          flow_session[:pii_from_doc].merge!(pii_from_doc)
          idv_session.clear_applicant!
        end
      end
      track_document_state(pii_from_doc[:state])
    end

    def in_person_cta_variant_testing_variables
      bucket = AbTests::IN_PERSON_CTA.bucket(document_capture_session_uuid)
      session[:in_person_cta_variant] = bucket
      {
        in_person_cta_variant_testing_enabled:
        IdentityConfig.store.in_person_cta_variant_testing_enabled,
        in_person_cta_variant_active: bucket,
      }
    end

    def stored_result
      return @stored_result if defined?(@stored_result)
      @stored_result = document_capture_session&.load_result
    end
  end
end
