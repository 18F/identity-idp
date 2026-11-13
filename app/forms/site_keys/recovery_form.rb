# frozen_string_literal: true

module SiteKeys
  # Opens a site key with the recovery code after a password reset, through the vault, so the key
  # is cached until the next password entry rewraps it.
  class RecoveryForm
    include ActiveModel::Model

    attr_accessor :code

    validates :code, presence: true
    validate :validate_code

    def initialize(vault:, code:)
      @vault = vault
      @code = code
    end

    def submit
      success = valid?
      self.code = nil

      FormResponse.new(success:, errors:)
    end

    private

    attr_reader :vault

    def validate_code
      return if code.blank?
      return if vault.recover(code).present?

      errors.add(:code, :site_key_recovery_code_incorrect, type: :site_key_recovery_code)
    rescue Encryption::EncryptionError
      errors.add(:code, :site_key_recovery_unavailable, type: :site_key_recovery_unavailable)
    end
  end
end
