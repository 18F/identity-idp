# frozen_string_literal: true

module OpenidConnect
  class DocumentImagesController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token
    before_action :authenticate_identity_via_bearer_token
    before_action :authenticate_client_via_assertion

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

      render_encrypted_image(image, artifact.content_type)
    end

    private

    # The image leaves only sealed to the service provider's registered certificate: one compact
    # JWE (RFC 7516 §7.1) whose `cty` header names the image's media type, served as
    # `application/jose` (RFC 7516 §9.2), so the edge, the logs and any intermediary see
    # ciphertext and the holder of the private key decrypts the same bytes the storage held.
    # A record with no usable RSA key is refused rather than answered in the clear.
    def render_encrypted_image(image, content_type)
      jwe = OpenidConnect::JweEncryptor.encrypt(
        image,
        service_provider: current_identity.service_provider_record,
        typ: nil,
        cty: content_type,
      )
      audit(success: true, encrypted: true)
      render plain: jwe, content_type: 'application/jose'
    rescue OpenidConnect::JweEncryptor::NoUsableKeyError, OpenSSL::OpenSSLError
      audit(success: false, denial_reason: :encryption_unavailable)
      render json: { error: 'server_error', error_description: 'encryption_unavailable' },
             status: :internal_server_error
    end

    # Unwrapping the stored key (KMS/rotation) and fetching from Redis can each
    # fail independently of the object simply being absent; all of these must
    # surface as an audited 404, never a 500.
    def read_image(artifact)
      doc_reader.read(name: artifact.storage_name, encryption_key: artifact.encryption_key)
    rescue Encryption::EncryptionError, Redis::BaseError
      nil
    end

    def audit(success:, denial_reason: nil, encrypted: nil)
      analytics.document_image_release(
        success:,
        image_type: params[:image_type],
        issuer: current_identity.service_provider,
        profile_id: active_profile&.id,
        denial_reason:,
        encrypted:,
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
      AuthnContextResolver.new(
        user: current_identity.user,
        service_provider: current_identity.service_provider_record,
        acr_values: current_identity.acr_values,
      ).result.identity_proofing?
    end

    def scoper
      @scoper ||= OpenidConnectAttributeScoper.new(current_identity.scope)
    end

    def active_profile
      current_identity.user&.active_profile
    end

    def doc_reader
      EncryptedDocStorage::DocReader.new
    end

    # Holding the access token is not enough to receive an image: the request also carries a
    # client assertion (RFC 7523 section 2.2), a JWT signed with the private key of the service
    # provider's registered certificate, sent as the form fields the token endpoint already
    # accepts and verified the same way, with this URL as its audience. A token copied from a
    # log or an intermediary is useless without that key, and a public client, which has no
    # registered key, cannot use this endpoint at all. Every refusal is audited.
    def authenticate_client_via_assertion
      if params[:client_assertion].blank? ||
         params[:client_assertion_type] != OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE
        return refuse_client(:client_assertion_required)
      end

      validator = OpenidConnectClientAssertionValidator.new(
        client_assertion: params[:client_assertion],
        client_id: current_identity.service_provider,
        service_provider: current_identity.service_provider_record,
        audience_url: api_openid_connect_document_image_url(image_type: params[:image_type]),
      )
      return if validator.valid?

      refuse_client(validator.errors.first.type)
    end

    def refuse_client(reason)
      audit(success: false, denial_reason: reason)
      render json: { error: 'invalid_client', error_description: reason.to_s },
             status: :unauthorized
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
