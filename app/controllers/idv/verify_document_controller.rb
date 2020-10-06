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

    def doc_auth_client
      @doc_auth_client ||= DocAuth::Client.client
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
      # decrypt when encryption is available
      uri = URI.parse(url)
      resp = s3_client.get_object(bucket: document_bucket, key: uri.path[1..-1])
      resp.body.read
    end
  end
end
