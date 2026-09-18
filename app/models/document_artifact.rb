# frozen_string_literal: true

class DocumentArtifact < ApplicationRecord
  IMAGE_TYPES = %w[front back passport selfie].freeze

  belongs_to :document_capture_session
  belongs_to :profile, optional: true

  validates :image_type, presence: true, inclusion: { in: IMAGE_TYPES }
  validates :storage_name, presence: true
  validates :encrypted_encryption_key, presence: true

  # Mirrors the S3 lifecycle on the escrow bucket so we never advertise or serve
  # an artifact whose underlying object has already been expired.
  scope :retained, -> { where(created_at: retention_cutoff..) }
  scope :expired, -> { where(created_at: ...retention_cutoff) }

  def self.retention_cutoff
    IdentityConfig.store.document_images_retention_days.days.ago
  end

  # Stores the per-image AES key encrypted at rest. Uses the durable
  # AttributeEncryptor (backed by attribute_encryption_key + its old-key queue)
  # so stored keys survive key rotation, unlike the session-scoped encryptors.
  def encryption_key=(raw_key)
    self.encrypted_encryption_key = raw_key.present? ? encryptor.encrypt(raw_key) : nil
  end

  def encryption_key
    return nil if encrypted_encryption_key.blank?

    encryptor.decrypt(encrypted_encryption_key)
  end

  private

  def encryptor
    Encryption::Encryptors::AttributeEncryptor.new
  end
end
