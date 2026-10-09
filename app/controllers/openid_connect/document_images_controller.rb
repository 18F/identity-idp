# frozen_string_literal: true

module OpenidConnect
  class DocumentImagesController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token

    attr_reader :current_identity

    def show
      unless scoper.document_images_requested? && document_images_shareable?
        audit(success: false, denial_reason: :not_authorized)
        return render json: { error: 'document_images sharing is not authorized' },
                      status: :forbidden
      end

      artifact = active_profile.document_artifacts.retained.find_by(image_type: params[:image_type])
      if artifact.blank?
        audit(success: false, denial_reason: :artifact_not_found)
        return head :not_found
      end

      image = read_image(artifact)
      if image.blank?
        audit(success: false, denial_reason: :object_unavailable)
        return head :not_found
      end

      audit(success: true)
      send_data image, type: artifact.content_type, disposition: 'inline'
    end

    private

    # Unwrapping the stored key (KMS/rotation) and fetching from S3 can each
    # fail independently of the object simply being absent; all of these must
    # surface as an audited 404, never a 500.
    def read_image(artifact)
      doc_reader.read(name: artifact.storage_name, encryption_key: artifact.encryption_key)
    rescue Encryption::EncryptionError, Aws::S3::Errors::ServiceError,
           Seahorse::Client::NetworkingError
      nil
    end

    def audit(success:, denial_reason: nil)
      analytics.document_image_release(
        success:,
        image_type: params[:image_type],
        issuer: current_identity.service_provider,
        profile_id: active_profile&.id,
        denial_reason:,
      )
    end

    def document_images_shareable?
      active_profile.present? &&
        identity_proofing_requested? &&
        current_identity.service_provider_record&.document_images_sharing_allowed? &&
        current_identity.biometric_sharing_consented?(active_profile)
    end

    # Mirrors the presenter's gate so the proxy never releases under an
    # authorization that did not actually request identity proofing.
    def identity_proofing_requested?
      result = AuthnContextResolver.new(
        user: current_identity.user,
        service_provider: current_identity.service_provider_record,
        acr_values: current_identity.acr_values,
      ).result
      result.identity_proofing? || result.ialmax?
    end

    def scoper
      @scoper ||= OpenidConnectAttributeScoper.new(current_identity.scope)
    end

    def active_profile
      current_identity.user&.active_profile
    end

    def doc_reader
      EncryptedDocStorage::DocReader.new(
        s3_enabled: IdentityConfig.store.doc_escrow_s3_storage_enabled,
      )
    end

    # The same access token the client used at userinfo, under the same rules: Bearer, or DPoP
    # with a proof for this method and URL when the token is bound to the client's key.
    def authenticate_identity_via_bearer_token
      verifier = AccessTokenVerifier.new(
        request.env['HTTP_AUTHORIZATION'],
        dpop_proof: request.headers['DPoP'].presence,
        http_method: request.request_method,
        http_url: api_openid_connect_document_image_url(image_type: params[:image_type]),
      )
      result, identity = verifier.submit
      attributes = result.to_h
      analytics.openid_connect_bearer_token(**attributes.except(:integration_errors))

      if result.success?
        @current_identity = identity
      else
        analytics.sp_integration_errors_present(**attributes[:integration_errors])
        challenge = verifier.www_authenticate
        response.headers['WWW-Authenticate'] = challenge if challenge
        render json: { error: verifier.errors[:access_token].join(' ') },
               status: :unauthorized
      end
    end
  end
end
