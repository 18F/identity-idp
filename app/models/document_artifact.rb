# frozen_string_literal: true

class DocumentArtifact < ApplicationRecord
  IMAGE_TYPES = %w[front back passport selfie].freeze

  belongs_to :document_capture_session
  belongs_to :profile, optional: true

  validates :image_type, presence: true, inclusion: { in: IMAGE_TYPES }
  validates :storage_name, presence: true
  validates :encrypted_encryption_key, presence: true

  # Mirrors the Redis TTL on the stored object so we never advertise or serve
  # an artifact whose underlying image has already expired.
  scope :retained, -> { where(created_at: retention_cutoff..) }
  scope :expired, -> { where(created_at: ...retention_cutoff) }

  def self.retention_cutoff
    IdentityConfig.store.document_images_ttl_seconds.seconds.ago
  end

  # The per-image AES key is wrapped with KMS under this person's encryption context, so the key
  # that opens the stored image is never readable from the database alone.
  def encryption_key=(raw_key)
    self.encrypted_encryption_key = raw_key.present? ? encryptor.encrypt(raw_key) : nil
  end

  def encryption_key
    return nil if encrypted_encryption_key.blank?

    encryptor.decrypt(encrypted_encryption_key)
  end

  private

  def encryptor
    Encryption::Encryptors::DocumentArtifactEncryptor.new(
      user_uuid: document_capture_session&.user&.uuid,
    )
  end
end
