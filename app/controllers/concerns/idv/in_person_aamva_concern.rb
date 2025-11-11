# frozen_string_literal: true

module Idv
  module InPersonAamvaConcern
    extend ActiveSupport::Concern

    AAMVA_REQUIRED_FIELDS = %i[
      first_name
      last_name
      dob
      state_id_number
      state_id_jurisdiction
    ].freeze

    def enqueue_aamva_job_and_redirect
      return true unless aamva_enabled?
      return false unless check_aamva_rate_limit

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

      true
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

      if current_state.missing?
        flash[:error] = I18n.t('idv.failure.timeout')
        delete_aamva_async_state
        render :show, locals: extra_view_variables
      end
    end

    private

    def aamva_enabled?
      IdentityConfig.store.idv_aamva_at_doc_auth_enabled
    end

    def aamva_proofer
      Proofing::Resolution::Plugins::AamvaPlugin.new
    end

    def validate_aamva_for_ipp
      return unless aamva_enabled?
      return if idv_session.ipp_already_proofed?

      pii = pii_from_user&.deep_dup
      return unless pii && aamva_required_fields_present?(pii)

      pii_fingerprint = calculate_pii_fingerprint(pii)

      begin
        aamva_result = aamva_proofer.call(
          applicant_pii: pii.freeze,
          current_sp: current_sp,
          state_id_address_resolution_result: nil,
          ipp_enrollment_in_progress: true,
          timer: JobHelpers::Timer.new,
          doc_auth_flow: true,
        )

        doc_auth_response = aamva_result.to_doc_auth_response

        store_aamva_result(doc_auth_response, aamva_result, pii_fingerprint)

        analytics.idv_ipp_aamva_verification_completed(
          success: doc_auth_response.success?,
          vendor_name: aamva_result.vendor_name,
          step: controller_name,
        )

        doc_auth_response
      rescue Proofing::TimeoutError => e
        handle_aamva_timeout(e)
      rescue StandardError => e
        handle_aamva_exception(e)
      end
    end

    def aamva_verification_succeeded?(aamva_response)
      return true unless aamva_response

      if aamva_response.errors.present?
        flash[:error] = I18n.t('idv.failure.verify.heading')
        false
      else
        true
      end
    end

    def aamva_required_fields_present?(pii)
      AAMVA_REQUIRED_FIELDS.all? { |field| pii[field].present? }
    end

    def calculate_pii_fingerprint(pii)
      relevant_fields = pii.slice(
        *AAMVA_REQUIRED_FIELDS, :identity_doc_address1,
        :identity_doc_city, :identity_doc_address_state,
        :identity_doc_zipcode, :address1, :city, :state, :zipcode
      )
      Digest::SHA256.hexdigest(relevant_fields.to_json)
    end

    def store_aamva_result(doc_auth_response, aamva_result, pii_fingerprint)
      idv_session.ipp_aamva_result = {
        'success' => doc_auth_response.success?,
        'errors' => doc_auth_response.errors,
        'vendor_name' => aamva_result.vendor_name,
        'checked_at' => Time.zone.now.iso8601,
        'pii_fingerprint' => pii_fingerprint,
      }
    end

    def handle_aamva_timeout(exception)
      analytics.idv_ipp_aamva_timeout(
        exception_class: exception.class.name,
        step: controller_name,
      )

      DocAuth::Response.new(
        success: false,
        errors: { network: I18n.t('idv.failure.timeout') },
        exception: exception,
      )
    end

    def handle_aamva_exception(exception)
      analytics.idv_ipp_aamva_exception(
        exception_class: exception.class.name,
        exception_message: exception.message,
        step: controller_name,
      )

      NewRelic::Agent.notice_error(exception) if defined?(NewRelic)

      DocAuth::Response.new(
        success: false,
        errors: { network: I18n.t('idv.failure.exceptions.internal_error') },
        exception: exception,
      )
    end

    def aamva_rate_limiter
      @aamva_rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :idv_doc_auth,
      )
    end

    def check_aamva_rate_limit
      return true unless aamva_rate_limiter.limited?

      analytics.idv_ipp_aamva_rate_limited(step: controller_name)
      flash[:error] = I18n.t('idv.failure.phone.rate_limited.heading')
      render :show, locals: extra_view_variables
      false
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
      result = current_state.result

      if result[:success]
        idv_session.ipp_aamva_result = result
        redirect_url = idv_session.ipp_aamva_redirect_url || idv_in_person_ssn_url
        delete_aamva_async_state
        redirect_to redirect_url
      else
        delete_aamva_async_state
        flash[:error] = I18n.t('idv.failure.verify.heading')
        render :show, locals: extra_view_variables
      end
    end

    def delete_aamva_async_state
      idv_session.ipp_aamva_document_capture_session_uuid = nil
      idv_session.ipp_aamva_redirect_url = nil
    end
  end
end
