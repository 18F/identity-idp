module Idv
  class VerifyDocumentController < ApplicationController
    include ApplicationHelper

    IMAGE_UPLOAD_PARAM_NAMES = %i[
      front_image back_image selfie_image front_image_data_url back_image_data_url
      selfie_image_data_url
    ].freeze

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
        client_response = doc_auth_client.post_images(
          front_image: read_file(params[:front_image_url]),
          back_image: read_file(params[:back_image_url]),
          selfie_image: read_file(params[:selfie_image_url]),
          liveness_checking_enabled: liveness_checking_enabled?,
        )

        analytics.track_event(
          Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
          client_response.to_h,
        )

        store_pii(client_response) if client_response.success?
        status = :bad_request unless client_response.success?
      else
        status = verify_document_form.status
      end

      presenter = ImageUploadResponsePresenter.new(
        form: verify_document_form,
        form_response: client_response || form_response,
      )

      render json: presenter,
             status: status || :ok
    end

    private

    def render_404_if_disabled
      render_not_found unless FeatureManagement.document_capture_step_enabled?
    end

    def verify_document_form
      Idv::ApiDocumentVerificationForm.
        new(params, liveness_checking_enabled: liveness_checking_enabled?)
    end

    def store_pii(doc_response)
      verify_document_form.document_capture_session.store_result_from_response(doc_response)
    end

    def doc_auth_client
      @doc_auth_client ||= DocAuth::Client.client
    end

    def call
      if request_should_use_stored_result?
        handle_stored_result
      else
        post_images_and_handle_result
      end
    end

    def post_images_and_handle_result
      response = post_images
      if response.success?
        save_proofing_components
        document_capture_session.store_result_from_response(response)
        extract_pii_from_doc(response)
        response
      else
        handle_document_verification_failure(response)
      end
    end

    def handle_document_verification_failure(response)
      mark_step_incomplete(:document_capture)
      notice = if liveness_checking_enabled?
                 { notice: I18n.t('errors.doc_auth.document_capture_info_with_selfie_html') }
               else
                 { notice: I18n.t('errors.doc_auth.document_capture_info_html') }
               end
      log_document_error(response)
      extra = response.to_h.merge(notice)
      failure(response.first_error_message, extra)
    end

    def handle_stored_result
      if stored_result.success?
        extract_pii_from_doc(stored_result)
      else
        extra = { stored_result_present: stored_result.present? }
        failure(I18n.t('errors.doc_auth.acuant_network_error'), extra)
      end
    end

    def stored_result
      @stored_document_capture_session_result ||= document_capture_session&.load_result
    end

    def request_should_use_stored_result?
      return false if stored_result.blank?
      IMAGE_UPLOAD_PARAM_NAMES.each do |param_name|
        return false if flow_params[param_name].present?
      end
      true
    end

    def ec2_data
      @ec2_data ||= LoginGov::Hostdata::EC2.load
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        region: ec2_data.region,
        http_open_timeout: 5,
        http_read_timeout: 5,
      )
    end

    def document_bucket
      Figaro.env.document_bucket
    end

    def read_file(url)
      # decrypt whe encryption is available
      uri = URI.parse(url)
      resp = s3_client.get_object(bucket: document_bucket, key: uri.path[1..-1])
      resp.body.read
    end
  end
end
