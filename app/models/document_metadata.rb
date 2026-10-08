# frozen_string_literal: true

# Document identifiers captured during proofing (document number, issue date,
# expiration date) that an allow-listed relying party needs for adjudication,
# alongside the document images. Encrypted at rest and released under the same
# document_images scope + biometric-sharing consent gate as the images; held to
# the same retention window.
class DocumentMetadata < ApplicationRecord
  self.table_name = 'document_metadata'

  FIELDS = %i[document_number document_issued document_expiration].freeze

  belongs_to :document_capture_session
  belongs_to :profile, optional: true

  validates :encrypted_document_data, presence: true

  scope :retained, -> { where(created_at: retention_cutoff..) }
  scope :expired, -> { where(created_at: ...retention_cutoff) }

  def self.retention_cutoff
    IdentityConfig.store.document_images_retention_days.days.ago
  end

  def retained?
    created_at.present? && created_at >= self.class.retention_cutoff
  end

  # @param [Hash] values a hash with any of FIELDS
  def document_data=(values)
    slice = values.to_h.symbolize_keys.slice(*FIELDS)
    self.encrypted_document_data = encryptor.encrypt(slice.to_json)
  end

  # @return [Hash] the decrypted document fields, symbolized
  def document_data
    return {} if encrypted_document_data.blank?

    JSON.parse(encryptor.decrypt(encrypted_document_data), symbolize_names: true)
  end

  private

  def encryptor
    Encryption::Encryptors::AttributeEncryptor.new
  end
end
