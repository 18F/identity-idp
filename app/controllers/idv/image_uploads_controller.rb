module Idv
  class ImageUploadsController < ApplicationController
    include ApplicationHelper # for liveness_checking_enabled?

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
        liveness_checking_enabled: liveness_checking_enabled?,
        service_provider: current_sp,
        analytics: analytics,
        uuid_prefix: current_sp&.app_id,
        irs_attempts_api_tracker: irs_attempts_api_tracker,
        store_encrypted_images: store_encrypted_images?,
      )
    end

    def store_encrypted_images?
      IdentityConfig.store.encrypted_document_storage_enabled
    end

    def liveness_checking_enabled?
      # todo: use config item,  UI options and sp configuration(ial_context)
      IdentityConfig.store.doc_auth_selfie_capture['enabled']
    end

    def ial_context
      @ial_context ||= IalContext.new(
        ial: sp_session_ial,
        service_provider: current_sp,
        user: current_user,
      )
    end
  end
end
