# frozen_string_literal: true

class DocumentImagesForm
  include ActiveModel::Model
  include Rails.application.routes.url_helpers

  validate :validate_client_assertion
  validate :validate_authorized
  validate :validate_artifact
  validate :validate_image

  def initialize(identity:, document_images_params:, doc_reader: EncryptedDocStorage::DocReader.new)
    @identity = identity
    @image_type = document_images_params[:image_type]
    @client_assertion = document_images_params[:client_assertion]
    @client_assertion_type = document_images_params[:client_assertion_type]
    @doc_reader = doc_reader
  end

  ErrorResponse = Struct.new(:status, :error, :error_description, keyword_init: true)

  def submit
    success = valid?

    FormResponse.new(
      success:,
      errors:,
    )
  end

  def error_response
    return nil if errors.blank?
    error_attribute = errors.attribute_names.first

    if [:code_verifier, :client_assertion].include?(error_attribute)
      ErrorResponse.new(
        status: :unauthorized,
        error: 'invalid_client',
        error_description: errors.full_messages.join(' '),
      )
    elsif [:scope, :acr_values].include?(error_attribute)
      ErrorResponse.new(
        status: :forbidden,
        error: 'document_images sharing is not authorized',
        error_description: errors.full_messages.join(' '),
      )
    elsif [:artifact, :image].include?(error_attribute)
      ErrorResponse.new(
        status: :not_found,
        error: 'images not found',
        error_description: errors.full_messages.join(' '),
      )
    else
      ErrorResponse.new(
        status: :not_found, error: 'something went wrong',
        error_description: errors.full_messages.join(' ')
      )
    end
  end

  def artifact
    @artifact ||= active_profile.document_artifacts&.retained&.find_by(image_type: image_type)
  end

  def image
    @image ||= read_image(artifact)
  end

  private

  attr_reader :identity, :image_type, :client_assertion, :client_assertion_type,
              :doc_reader, :scope, :acr_values

  def validate_client_assertion
    if client_assertion.blank? || client_assertion_type != OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE
      return errors.add(
        :code_verifier, 'client_assertion_required',
        type: :client_assertion_required
      )
    end

    return if validator.valid?

    validator.errors.each do |error|
      errors.add(error.attribute, error.message, type: error.type)
    end
  end

  def validate_authorized
    return if errors.any?
    unless document_images_requested?
      errors.add(:scope, 'no_valid_scope', type: :no_valid_scope)

      return
    end

    unless verified_identity?
      errors.add(:acr_values, 'no_identity_verification', type: :no_identity_verification)

      return
    end

    unless identity.service_provider_record&.document_images_sharing_allowed?
      errors.add(:scope, 'unauthorized_scope', type: :unauthorized_scope)

      return
    end

    return if identity.biometric_sharing_consented?(active_profile)

    errors.add(:scope, 'not_consented_to', type: :not_consented_to)
  end

  def validate_artifact
    return if errors.any?
    return if artifact.present?

    errors.add(:artifact, 'not_found', type: :not_found)
  end

  def validate_image
    return if errors.any?
    return if image.present?

    errors.add(:image, 'object_unavailable', type: :object_unavailable)
  end

  def validator
    @validator ||= OpenidConnectClientAssertionValidator.new(
      client_assertion:,
      client_id: identity.service_provider,
      service_provider: identity.service_provider_record,
      audience_url:,
    )
  end

  def verified_identity?
    active_profile.present? && identity_proofing_requested?
  end

  def document_images_requested?
    scoper.document_images_requested?
  end

  def identity_proofing_requested?
    AuthnContextResolver.new(
      user: identity.user,
      service_provider: identity.service_provider_record,
      acr_values: identity.acr_values,
    ).result.identity_proofing?
  end

  def scoper
    @scoper ||= OpenidConnectAttributeScoper.new(identity.scope)
  end

  def active_profile
    @active_profile ||= identity.user&.active_profile
  end

  # Unwrapping the stored key (KMS/rotation) and fetching from Redis can each
  # fail independently of the object simply being absent; all of these must
  # surface as an audited 404, never a 500.
  def read_image(artifact)
    doc_reader.read(name: artifact&.storage_name, encryption_key: artifact&.encryption_key)
  rescue Encryption::EncryptionError, Redis::BaseError
    nil
  end

  def audience_url
    Rails.application.routes.url_helpers.api_openid_connect_document_image_url(image_type:)
  end

  def url_options
    {}
  end
end
