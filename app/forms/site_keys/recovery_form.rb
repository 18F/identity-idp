# frozen_string_literal: true

module SiteKeys
  class RecoveryForm
    include ActiveModel::Model

    attr_accessor :code
    attr_reader :recovered_root

    validates :code, presence: true
    validate :validate_code

    def initialize(user:, code:)
      @user = user
      @code = code
    end

    def submit
      success = valid?
      reset_sensitive_fields

      FormResponse.new(success:, errors:)
    end

    private

    attr_reader :user

    def validate_code
      return if code.blank?
      return if code_opens_root?

      errors.add(:code, :site_key_recovery_code_incorrect, type: :site_key_recovery_code)
    end

    def code_opens_root?
      record = user.site_key_root
      @recovered_root = record && SiteKeys::RootCipher.new(user).recover(record, code)
      @recovered_root.present?
    rescue Encryption::EncryptionError
      errors.add(:code, :site_key_recovery_unavailable, type: :site_key_recovery_unavailable)
      true
    end

    def reset_sensitive_fields
      self.code = nil
    end
  end
end
