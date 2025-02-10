# frozen_string_literal: true

module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      def initialize(flow)
        super(flow, :doc_auth)
      end

      private

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
        redirect_to rate_limited_url
        DocAuth::Response.new(
          success: false,
          errors: { limit: I18n.t('doc_auth.errors.rate_limited_heading') },
        )
      end

      def rate_limited_url
        idv_session_errors_rate_limited_url
      end

      def user_id
        current_user ? current_user.id : user_id_from_token
      end

      def sp_session
        session.fetch(:sp, {})
      end

      def create_document_capture_session(key)
        document_capture_session = DocumentCaptureSession.create(
          user_id: user_id,
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
