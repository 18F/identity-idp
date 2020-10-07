# API to submit image urls for processing to verification vendor and poll for results

module Idv
  class VerifyDocumentsController < ApplicationController
    include ApplicationHelper

    before_action :render_404_if_disabled

    respond_to :json

    def index
      analytics.track_event(Analytics::IDV_DOC_AUTH_DOCUMENT_STATUS)

      render json: { status: :success }
    end

    def create
      form_response = verify_document_form.submit

      analytics.track_event(Analytics::IDV_DOC_AUTH_SUBMITTED_DOCUMENT_PROCESSING_FORM,
                            form_response.to_h)

      if form_response.success?
        client_response = VendorDocumentVerificationJob.perform(
          document_capture_session_uuid: verify_document_form.document_capture_session_uuid,
          front_image_url: read_file(params[:front_image_url]),
          back_image_url: read_file(params[:back_image_url]),
          selfie_image_url: read_file(params[:selfie_image_url]),
          liveness_checking_enabled: liveness_checking_enabled?,
        )

        analytics.track_event(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          client_response.to_h,
        )

        status = :bad_request unless client_response.success?
      else
        status = verify_document_form.status
      end

      render json: { status: status }
    end

    private

    def render_404_if_disabled
      render_not_found unless FeatureManagement.document_capture_step_enabled?
    end

    def verify_document_form
      Idv::ApiDocumentVerificationForm.
        new(params, liveness_checking_enabled: liveness_checking_enabled?)
    end
  end
end
