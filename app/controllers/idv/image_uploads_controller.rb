module Idv
  class ImageUploadsController < ApplicationController
    include ApplicationHelper # for liveness_checking_enabled?

    respond_to :json

    def create
      image_upload_form_response = image_upload_form.submit

      flow_path = user_session&.dig('idv/doc_auth', :flow_path)

      presenter = ImageUploadResponsePresenter.new(
        form_response: image_upload_form_response,
        url_options: url_options,
        flow_path: flow_path,
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
        irs_attempts_api_tracker: irs_attempts_api_tracker,
        store_encrypted_images: store_encrypted_images?,
      )
    end

    def store_encrypted_images?
      IdentityConfig.store.encrypted_document_storage_enabled &&
        irs_attempts_api_enabled_for_session?
    end
  end
end
