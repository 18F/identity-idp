module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :doc_auth)
      end

      private

      def idv_throttle_params
        [current_user.id, :idv_resolution]
      end

      def attempter_increment
        Throttler::Increment.call(*idv_throttle_params)
      end

      def attempter_throttled?
        Throttler::IsThrottled.call(*idv_throttle_params)
      end

      def idv_failure(result)
        attempter_increment if result.extra.dig(:proofing_results, :exception).blank?
        if attempter_throttled?
          @flow.analytics.track_event(
            Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
            throttle_type: :idv_resolution,
          )
          redirect_to idv_session_errors_failure_url
        elsif result.extra.dig(:proofing_results, :exception).present?
          redirect_to idv_session_errors_exception_url
        else
          redirect_to idv_session_errors_warning_url
        end
        result
      end

      def save_proofing_components
        Db::ProofingComponent::Add.call(user_id, :document_check, DocAuthRouter.doc_auth_vendor)
        Db::ProofingComponent::Add.call(user_id, :document_type, 'state_id')
        return unless liveness_checking_enabled?
        Db::ProofingComponent::Add.call(user_id, :liveness_check, DocAuthRouter.doc_auth_vendor)
      end

      def extract_pii_from_doc(response)
        current_user = User.find(user_id)
        flow_session[:pii_from_doc] = response.pii_from_doc.merge(
          uuid: current_user.uuid,
          phone: current_user.phone_configurations.take&.phone,
        )
      end

      def user_id_from_token
        flow_session[:doc_capture_user_id]
      end

      def hybrid_flow_mobile?
        user_id_from_token.present?
      end

      def throttled_response
        @flow.analytics.track_event(
          Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
          throttle_type: :idv_acuant,
        )
        redirect_to throttled_url
        IdentityDocAuth::Response.new(
          success: false,
          errors: { limit: I18n.t('errors.doc_auth.acuant_throttle') },
        )
      end

      def throttled_url
        return idv_session_errors_throttled_url unless @flow.class == Idv::Flows::RecoveryFlow
        idv_session_errors_recovery_throttled_url
      end

      def throttled_else_increment
        Throttler::IsThrottledElseIncrement.call(user_id, :idv_acuant)
      end

      def user_id
        current_user ? current_user.id : user_id_from_token
      end

      def add_cost(token, transaction_id: nil)
        issuer = sp_session[:issuer].to_s
        Db::SpCost::AddSpCost.call(issuer, 2, token, transaction_id: transaction_id)
        Db::ProofingCost::AddUserProofingCost.call(user_id, token)
      end

      def add_costs(result)
        Db::AddDocumentVerificationAndSelfieCosts.
          new(user_id: user_id,
              issuer: sp_session[:issuer].to_s,
              liveness_checking_enabled: liveness_checking_enabled?).
          call(result)
      end

      def sp_session
        session.fetch(:sp, {})
      end

      def liveness_checking_enabled?
        FeatureManagement.liveness_checking_enabled? && (no_sp? || sp_session[:ial2_strict])
      end

      def create_document_capture_session(key)
        document_capture_session = DocumentCaptureSession.create(
          user_id: user_id,
          issuer: sp_session[:issuer],
          ial2_strict: sp_session[:ial2_strict],
        )
        flow_session[key] = document_capture_session.uuid

        document_capture_session
      end

      def document_capture_session
        @document_capture_session ||= DocumentCaptureSession.find_by(
          uuid: flow_session[document_capture_session_uuid_key],
        )
      end

      def no_sp?
        sp_session[:issuer].blank?
      end

      def document_capture_session_uuid_key
        :document_capture_session_uuid
      end

      def verify_step_document_capture_session_uuid_key
        :idv_verify_step_document_capture_session_uuid
      end

      def cac_verify_document_capture_session_uuid_key
        :cac_verify_step_document_capture_session_uuid
      end

      def recover_verify_document_capture_session_uuid_key
        :idv_recover_verify_step_document_capture_session_uuid
      end

      def verify_document_capture_session_uuid_key
        :verify_document_action_document_capture_session_uuid
      end

      delegate :idv_session, :session, to: :@flow
    end
  end
end
