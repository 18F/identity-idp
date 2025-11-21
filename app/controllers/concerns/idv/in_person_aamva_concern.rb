# frozen_string_literal: true

module Idv
  module InPersonAamvaConcern
    extend ActiveSupport::Concern

    def start_aamva_async_state
      return if idv_session.ipp_aamva_document_capture_session_uuid

      document_capture_session = DocumentCaptureSession.create!(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
        requested_at: Time.zone.now,
      )

      idv_session.ipp_aamva_document_capture_session_uuid = document_capture_session.uuid

      document_capture_session.create_proofing_session

      encrypted_arguments = encrypt_pii_for_job(pii_from_user)

      enqueue_job(
        document_capture_session: document_capture_session,
        encrypted_arguments: encrypted_arguments,
      )
    end

    def process_aamva_async_state
      current_state = load_aamva_async_state

      if current_state.done?
        handle_aamva_async_done(current_state)
        return
      end

      if current_state.in_progress?
        analytics.idv_ipp_aamva_verification_polling_wait
        render 'shared/wait'
        return
      end

      if current_state.none?
        analytics.idv_in_person_proofing_state_id_visited(**analytics_arguments)
        render :show, locals: extra_view_variables
        return
      end

      if current_state.missing?
        analytics.idv_ipp_aamva_proofing_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        delete_aamva_async_state
        render :show, locals: extra_view_variables
      end
    end

    private

    def aamva_enabled?
      IdentityConfig.store.idv_aamva_at_doc_auth_enabled
    end

    def encrypt_pii_for_job(pii)
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: pii }.to_json,
      )
    end

    def enqueue_job(document_capture_session:, encrypted_arguments:)
      if IdentityConfig.store.ruby_workers_idv_enabled
        IppAamvaProofingJob.perform_later(
          result_id: document_capture_session.result_id,
          encrypted_arguments: encrypted_arguments,
          trace_id: amzn_trace_id,
          user_id: current_user.id,
          service_provider_issuer: sp_session[:issuer],
        )
      else
        IppAamvaProofingJob.perform_now(
          result_id: document_capture_session.result_id,
          encrypted_arguments: encrypted_arguments,
          trace_id: amzn_trace_id,
          user_id: current_user.id,
          service_provider_issuer: sp_session[:issuer],
        )
      end
    end

    def load_aamva_async_state
      dcs_uuid = idv_session.ipp_aamva_document_capture_session_uuid
      return ProofingSessionAsyncResult.none if dcs_uuid.nil?

      dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
      return ProofingSessionAsyncResult.missing if dcs.nil?

      proofing_result = dcs.load_proofing_result
      return ProofingSessionAsyncResult.missing if proofing_result.nil?

      proofing_result
    end

    def handle_aamva_async_done(current_state)
      if rate_limit_redirect!(:idv_doc_auth, step_name: 'ipp_state_id')
        delete_aamva_async_state
        return
      end

      result = current_state.result

      analytics.idv_ipp_aamva_verification_completed(
        success: result[:success],
        vendor_name: result[:vendor_name],
        step: controller_name,
      )

      if result[:success]
        idv_session.ipp_aamva_result = result
        redirect_url = idv_session.ipp_aamva_redirect_url || idv_in_person_ssn_url
        delete_aamva_async_state
        redirect_to redirect_url
      else
        delete_aamva_async_state
        flash.now[:error] = I18n.t('idv.failure.verify.heading')
        render :show, locals: extra_view_variables
      end
    end

    def delete_aamva_async_state
      idv_session.ipp_aamva_document_capture_session_uuid = nil
      idv_session.ipp_aamva_redirect_url = nil
    end
  end
end
