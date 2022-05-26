module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :doc_auth)
      end

      private

      def throttle
        @throttle ||= RedisThrottle.new(
          user: current_user,
          throttle_type: :idv_resolution,
        )
      end

      def idv_failure(result)
        throttle.increment! if result.extra.dig(:proofing_results, :exception).blank?
        if throttle.throttled?
          @flow.analytics.track_event(
            Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
            throttle_type: :idv_resolution,
            step_name: self.class.name,
          )
          redirect_to idv_session_errors_failure_url
        elsif result.extra.dig(:proofing_results, :exception).present?
          @flow.analytics.idv_doc_auth_exception_visited(
            step_name: self.class.name,
            remaining_attempts: throttle.remaining_count,
          )
          redirect_to idv_session_errors_exception_url
        else
          @flow.analytics.idv_doc_auth_warning_visited(
            step_name: self.class.name,
            remaining_attempts: throttle.remaining_count,
          )
          redirect_to idv_session_errors_warning_url
        end
        result
      end

      def save_proofing_components
        return unless current_user

        doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
          discriminator: flow_session[document_capture_session_uuid_key],
        )

        component_attributes = {
          document_check: doc_auth_vendor,
          document_type: 'state_id',
        }
        component_attributes[:liveness_check] = doc_auth_vendor if liveness_checking_enabled?
        ProofingComponent.create_or_find_by(user: current_user).update(component_attributes)
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

        flow_session[:pii_from_doc] = pii_from_doc if store_in_session
        track_document_state(pii_from_doc[:state])
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
          throttle_type: :idv_doc_auth,
        )
        redirect_to throttled_url
        DocAuth::Response.new(
          success: false,
          errors: { limit: I18n.t('errors.doc_auth.throttled_heading') },
        )
      end

      def throttled_url
        idv_session_errors_throttled_url
      end

      def throttled_else_increment
        RedisThrottle.new(
          user: effective_user,
          throttle_type: :idv_doc_auth,
        ).throttled_else_increment?
      end

      # Ideally we would not have to re-implement the EffectiveUser mixin
      # but flow_session sometimes != controller#session
      def effective_user
        current_user || User.find(user_id_from_token)
      end

      def user_id
        current_user ? current_user.id : user_id_from_token
      end

      def add_cost(token, transaction_id: nil)
        Db::SpCost::AddSpCost.call(current_sp, 2, token, transaction_id: transaction_id)
        Db::ProofingCost::AddUserProofingCost.call(user_id, token)
      end

      def add_costs(result)
        Db::AddDocumentVerificationAndSelfieCosts.
          new(user_id: user_id,
              service_provider: current_sp,
              liveness_checking_enabled: liveness_checking_enabled?).
          call(result)
      end

      def sp_session
        session.fetch(:sp, {})
      end

      def liveness_checking_enabled?
        return false if !FeatureManagement.liveness_checking_enabled?
        return sp_session[:ial2_strict] if sp_session.key?(:ial2_strict)
        !!current_user.decorate.password_reset_profile&.strict_ial2_proofed?
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

      def document_capture_session_uuid_key
        :document_capture_session_uuid
      end

      def verify_step_document_capture_session_uuid_key
        :idv_verify_step_document_capture_session_uuid
      end

      def verify_document_capture_session_uuid_key
        :verify_document_action_document_capture_session_uuid
      end

      def track_document_state(state)
        return unless IdentityConfig.store.state_tracking_enabled && state
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return unless doc_auth_log
        doc_auth_log.state = state
        doc_auth_log.save!
      end

      delegate :idv_session, :session, :flow_path, to: :@flow
    end
  end
end
