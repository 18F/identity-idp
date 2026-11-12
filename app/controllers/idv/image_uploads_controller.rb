# frozen_string_literal: true

module Idv
  class ImageUploadsController < ApplicationController
    respond_to :json

    def create
      image_upload_form_response = image_upload_form.submit

      presenter = ImageUploadResponsePresenter.new(
        form_response: image_upload_form_response,
        url_options: url_options,
      )

      render json: presenter, status: presenter.status
    end

    private

    def image_upload_form
      @image_upload_form ||= Idv::ApiImageUploadForm.new(
        params,
        document_capture_session: authorized_document_capture_session,
        acuant_sdk_upgrade_ab_test_bucket: ab_test_bucket(:ACUANT_SDK),
        analytics:,
        attempts_api_tracker:,
        fraud_ops_tracker:,
        liveness_checking_required: resolved_authn_context_result.facial_match?,
        service_provider: current_sp,
        uuid_prefix: current_sp&.app_id,
      )
    end

    def authorized_document_capture_session
      uuid = params[:document_capture_session_uuid]
      return if uuid.blank?

      if current_user
        current_user.document_capture_sessions.find_by(uuid:)
      elsif hybrid_session_matches?(uuid)
        hybrid_document_capture_session(uuid)
      end
    end

    def hybrid_session_matches?(uuid)
      session[:doc_capture_user_id].present? && session[:document_capture_session_uuid] == uuid
    end

    def hybrid_document_capture_session(uuid)
      document_capture_session = DocumentCaptureSession.find_by(
        uuid:,
        user_id: session[:doc_capture_user_id],
      )
      return if document_capture_session.nil?
      return if document_capture_session.expired? || document_capture_session.cancelled_at

      document_capture_session
    end
  end
end
