module Idv
  class ImageUploadsController < ApplicationController
    include ApplicationHelper # for liveness_checking_enabled?

    respond_to :json

    def create
      image_form = Idv::ApiImageUploadForm.new(
        params,
        liveness_checking_enabled: liveness_checking_enabled?
      )

      form_response = image_form.submit

      if form_response.success?
        doc_response = doc_auth_client.post_images(
          front_image: image_form.front,
          back_image: image_form.back,
          selfie_image: image_form.back,
          liveness_checking_enabled: liveness_checking_enabled?
        )

        store_pii(doc_response) if doc_response.success?

        render_form_response(doc_response)
      else
        render_form_response(form_response)
      end
    end

    private

    def store_pii(doc_response)
      # stub for future PR
    end

    def render_form_response(form_response)
      if form_response.success?
        render json: {
          success: true
        }
      else
        render json: form_response.to_h,
               status: :bad_request
      end
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuthClient.client
    end
  end
end
