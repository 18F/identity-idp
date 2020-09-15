module Idv
  class ImageUploadsController < ApplicationController
    include ApplicationHelper # for liveness_checking_enabled?

    before_action :render_404_if_disabled

    respond_to :json

    def create
      form_response = image_form.submit

      if form_response.success?
        client_response = doc_auth_client.post_images(
          front_image: image_form.front.read,
          back_image: image_form.back.read,
          selfie_image: image_form.selfie&.read,
          liveness_checking_enabled: liveness_checking_enabled?,
        )

        if client_response.success?
          store_pii(client_response)
        else
          log_document_error(client_response)
          status = :bad_request
        end
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

    def user_id
      image_form.document_capture_session.user_id
    end

    def log_document_error(response)
      return unless response.is_a?(DocAuth::Acuant::Responses::GetResultsResponse)
      Funnel::DocAuth::LogDocumentError.call(user_id, response&.result_code&.name.to_s)
    end
  end
end
