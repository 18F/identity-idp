# frozen_string_literal: true

module Idv
  class ImageUploadsController < ApplicationController
    respond_to :json

    def create
      puts "\n#{'+' * 10} ImageUploadsController#create"
      image_upload_form_response = image_upload_form.submit
      puts "#{'+' * 4} image_upload_form_response[:doc_auth_result]: #{image_upload_form_response.to_h[:doc_auth_result]}\n\n"

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
        service_provider: current_sp,
        analytics: analytics,
        uuid_prefix: current_sp&.app_id,
        liveness_checking_required: resolved_authn_context_result.biometric_comparison?,
      )
    end
  end
end
