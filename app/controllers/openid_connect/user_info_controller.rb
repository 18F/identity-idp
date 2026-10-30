# frozen_string_literal: true

module OpenidConnect
  class UserInfoController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token

    attr_reader :current_identity

    def show
      user_info = OpenidConnectUserInfoPresenter.new(current_identity).user_info

      if service_provider&.userinfo_encrypted_response?
        render_encrypted_user_info(user_info)
      else
        render json: user_info
      end
    end

    private

    def service_provider
      current_identity.service_provider_record
    end

    def render_encrypted_user_info(user_info)
      jwe = OpenidConnect::JweEncryptor.encrypt(user_info.to_json, service_provider:)
      audit_document_image_release(user_info) if user_info.key?(:document_images)
      render plain: jwe, content_type: 'application/jwt'
    rescue OpenidConnect::JweEncryptor::NoUsableKeyError, OpenSSL::OpenSSLError => e
      analytics.openid_connect_userinfo_encryption_failed(
        client_id: service_provider.issuer,
        error: e.class.name,
      )
      render json: {
        error: 'server_error',
        error_description: t('openid_connect.user_info.errors.encryption_unavailable'),
      }, status: :internal_server_error
    end

    # Every response that carries document images is recorded with the image types, the
    # issuer and the profile, never the images. The claim exists only inside the encrypted
    # response, so the record is written once the response has been sealed.
    def audit_document_image_release(user_info)
      analytics.document_image_release(
        success: true,
        image_types: user_info[:document_images].keys.map(&:to_s),
        issuer: service_provider.issuer,
        profile_id: current_identity.user&.active_profile&.id,
      )
    end

    def authenticate_identity_via_bearer_token
      verifier = AccessTokenVerifier.new(request.env['HTTP_AUTHORIZATION'])
      response, identity = verifier.submit
      attributes = response.to_h
      analytics.openid_connect_bearer_token(
        **attributes.except(:integration_errors),
        encrypted: identity&.service_provider_record&.userinfo_encrypted_response?,
      )

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
