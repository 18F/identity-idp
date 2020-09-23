module Idv
  class ImageUploadsController < ApplicationController
    include ApplicationHelper # for liveness_checking_enabled?

    before_action :render_404_if_disabled

    respond_to :json

    def create
      form_response = image_form.submit

      analytics.track_event(Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM, form_response.to_h)

      if form_response.success?
        client_response = doc_auth_client.post_images(
          front_image: image_form.front.read,
          back_image: image_form.back.read,
          selfie_image: image_form.selfie&.read,
          liveness_checking_enabled: liveness_checking_enabled?,
        )

        analytics.track_event(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          client_response.to_h,
        )

        store_pii(client_response) if client_response.success?
        status = :bad_request unless client_response.success?
      else
        status = image_form.status
      end

      presenter = ImageUploadResponsePresenter.new(
        form: image_form,
        form_response: client_response || form_response,
      )

      render json: presenter,
             status: status || :ok
    end

    private

    def render_404_if_disabled
      render_not_found unless FeatureManagement.document_capture_step_enabled?
    end

    def image_form
      @image_form ||= Idv::ApiImageUploadForm.new(
        params,
        liveness_checking_enabled: liveness_checking_enabled?,
      )
    end

    def store_pii(doc_response)
      image_form.document_capture_session.store_result_from_response(doc_response)
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuth::Client.client
    end
  end
end
