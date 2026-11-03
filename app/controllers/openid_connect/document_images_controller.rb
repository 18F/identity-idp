# frozen_string_literal: true

module OpenidConnect
  class DocumentImagesController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token

    attr_reader :current_identity

    def show
      result = document_images_form.submit

      unless result.success?
        track_analytics(result.to_h)
        return render_document_images_error
      end

      render_encrypted_image
    end

    private

    def render_encrypted_image
      jwe = OpenidConnect::JweEncryptor.encrypt(
        document_images_form.image,
        service_provider: current_identity.service_provider_record,
        typ: nil,
        cty: document_images_form.artifact.content_type,
      )
      track_analytics({ success: true }, encrypted: true)

      render plain: jwe, content_type: 'application/jose'
    rescue OpenidConnect::JweEncryptor::NoUsableKeyError, OpenSSL::OpenSSLError
      track_analytics(
        {
          success: false,
          error_details: { encryption: { encryption_unavailable: true } },
        },
      )

      render json: { error: 'server_error', error_description: 'encryption_unavailable' },
             status: :internal_server_error
    end

    def document_images_form
      @document_images_form ||= DocumentImagesForm.new(
        identity: current_identity,
        document_images_params:,
        audience_url:
           api_openid_connect_document_image_url(image_type: params[:image_type]),
      )
    end

    def document_images_params
      params.permit(:image_type, :client_assertion, :client_assertion_type)
    end

    def render_document_images_error
      error_response = document_images_form.error_response

      render json: {
        error: error_response.error,
        error_description: error_response.error_description,
      }.compact, status: error_response.status
    end

    def track_analytics(result, encrypted: nil)
      analytics.document_image_release(
        **result,
        encrypted:,
        image_type: params[:image_type],
        issuer: current_identity.service_provider,
        profile_id: current_identity.user&.active_profile&.id,
      )
    end

    def authenticate_identity_via_bearer_token
      verifier = AccessTokenVerifier.new(request.env['HTTP_AUTHORIZATION'])
      response, identity = verifier.submit
      attributes = response.to_h
      analytics.openid_connect_bearer_token(**attributes.except(:integration_errors))

      if response.success?
        @current_identity = identity
      else
        analytics.sp_integration_errors_present(**attributes[:integration_errors])
        render json: { error: verifier.errors[:access_token].join(' ') },
               status: :unauthorized
      end
    end
  end
end
