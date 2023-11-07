module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :doc_auth)
      end

      private

      def save_proofing_components
        return unless current_user

        doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
          discriminator: flow_session[document_capture_session_uuid_key],
          analytics: @flow.analytics,
        )

        component_attributes = {
          document_check: doc_auth_vendor,
          document_type: 'state_id',
        }
        ProofingComponent.create_or_find_by(user: current_user).update(component_attributes)
      end

      def user_id_from_token
        flow_session[:doc_capture_user_id]
      end

      def hybrid_flow_mobile?
        user_id_from_token.present?
      end

      def rate_limited_response
        @flow.analytics.rate_limit_reached(
          limiter_type: :idv_doc_auth,
        )
        @flow.irs_attempts_api_tracker.idv_document_upload_rate_limited
        redirect_to rate_limited_url
        DocAuth::Response.new(
          success: false,
          errors: { limit: I18n.t('errors.doc_auth.rate_limited_heading') },
        )
      end

      def rate_limited_url
        idv_session_errors_rate_limited_url
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
        Db::SpCost::AddSpCost.call(current_sp, 2, token, transaction_id:)
      end

      def add_costs(result)
        Db::AddDocumentVerificationAndSelfieCosts.
          new(user_id:,
              service_provider: current_sp).
          call(result)
      end

      def sp_session
        session.fetch(:sp, {})
      end

      def create_document_capture_session(key)
        document_capture_session = DocumentCaptureSession.create(
          user_id:,
          issuer: sp_session[:issuer],
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

      delegate :idv_session, :session, :flow_path, to: :@flow
    end
  end
end
