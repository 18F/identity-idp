module Idv
  class ImageUploadsController < ApplicationController
    include ApplicationHelper # for liveness_checking_enabled?

    before_action :render_404_if_disabled

    respond_to :json

    def create
      form_response = image_form.submit

      if form_response.success?
        doc_response = doc_auth_client.post_images(
          front_image: image_form.front.read,
          back_image: image_form.back.read,
          selfie_image: image_form.selfie&.read,
          liveness_checking_enabled: liveness_checking_enabled?,
        )

        store_pii(doc_response) if doc_response.success?

        render_form_response(doc_response)
      else
        render_form_response(form_response)
      end
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

    def render_form_response(form_response)
      if form_response.success?
        render json: {
          success: true,
        }
      else
        errors = form_response.errors.flat_map do |key, errs|
          Array(errs).map { |err| { field_name: key, error_message: err } }
        end

        render json: form_response.to_h.merge(errors: errors),
               status: :bad_request
      end
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuth::Client.client
    end
  end
end
