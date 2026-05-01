# frozen_string_literal: true

module Idv
  module HybridMobile
    class MdlController < ApplicationController
      include Idv::AvailabilityConcern
      include HybridMobileConcern
      include DocumentCaptureConcern

      CHALLENGE_SESSION_KEY = :mdl_mattr_challenge

      before_action :check_valid_document_capture_session
      before_action :confirm_mdl_enabled
      before_action :override_csp_for_mattr, only: :show

      def show
        @mattr_application_id = IdentityConfig.store.mattr_application_id
        @mattr_tenant_url = IdentityConfig.store.mattr_tenant_url
        @callback_path = idv_hybrid_mobile_mdl_callback_path
        @challenge = SecureRandom.urlsafe_base64(32)

        session[CHALLENGE_SESSION_KEY] = @challenge
      end

      def callback
        session_id = params[:session_id].to_s
        stored_challenge = session[CHALLENGE_SESSION_KEY]

        if session_id.blank? || stored_challenge.blank?
          return render_error('invalid session')
        end

        result = Mattr::VerifierClient.new.get_presentation_result(session_id: session_id)

        Rails.logger.info(
          "[HybridMobile::MdlController] mattr result: " \
          "#{result.except('credentials').to_json}, stored_challenge=#{stored_challenge.inspect}",
        )

        if result['challenge'] != stored_challenge
          return render_error('challenge mismatch')
        end

        credential = result.dig('credentials', 0)
        return render_error('no credential returned') if credential.blank?

        parser = Mattr::ResponseParser.new(credential)
        unless parser.parse
          Rails.logger.error(
            "[HybridMobile::MdlController] parse failed: #{parser.errors.join(', ')}",
          )
          return render_error('credential parsing failed')
        end

        store_mdl_result(parser.to_pii)
        session.delete(CHALLENGE_SESSION_KEY)

        render json: {
          status: 'complete',
          redirect: idv_hybrid_mobile_capture_complete_url,
        }
      rescue Faraday::Error => e
        Rails.logger.error("[HybridMobile::MdlController] result fetch failed: #{e.message}")
        render_error('verification failed')
      end

      private

      def confirm_mdl_enabled
        return if IdentityConfig.store.mdl_verification_enabled
        redirect_to idv_hybrid_mobile_choose_id_type_url
      end

      def override_csp_for_mattr
        policy = current_content_security_policy
        policy.connect_src(*policy.connect_src, IdentityConfig.store.mattr_tenant_url)
        request.content_security_policy = policy
      end

      def render_error(message)
        render json: { status: 'error', message: message }, status: :unprocessable_content
      end

      def store_mdl_result(pii)
        result = DocumentCaptureSessionResult.new(
          id: SecureRandom.uuid,
          success: true,
          pii: pii.to_h,
          captured_at: Time.zone.now,
          attention_with_barcode: false,
          doc_auth_success: true,
          selfie_status: :not_processed,
          errors: {},
          mrz_status: :not_processed,
          aamva_status: :not_processed,
          attempt: 1,
        )

        EncryptedRedisStructStorage.store(
          result,
          expires_in:
            IdentityConfig.store.doc_capture_request_valid_for_minutes.minutes.in_seconds,
        )
        document_capture_session.update!(result_id: result.id)
      end
    end
  end
end
