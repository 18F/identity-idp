class BackupCodeConfiguration < ApplicationRecord
  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :code)

  include BackupCodeEncryptedAttributeOverrides

  belongs_to :user

  attr_accessor :skip_legacy_encryption
  alias_method :skip_legacy_encryption?, :skip_legacy_encryption

  def self.unused
    where(used_at: nil)
  end

  def mfa_enabled?
    user.backup_code_configurations.unused.any? if user
  end

  def selection_presenters
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new(self)]
  end

  def friendly_name
    :backup_codes
  end

  def self.selection_presenters(set)
    if set.any?
      set.first.selection_presenters
    else
      []
    end
  end

  class << self
    def find_with_code(code:, user_id:)
      return if code.blank?
      code = code.downcase.strip

      user_salt_costs = select(:code_salt, :code_cost).
        distinct.
        where(user_id: user_id).
        where.not(code_salt: nil).where.not(code_cost: nil).
        pluck(:code_salt, :code_cost)

      salted_fingerprints = user_salt_costs.map do |salt, cost|
        scrypt_password_digest(password: code, salt: salt, cost: cost)
      end

      where(
        code_fingerprint: create_fingerprint(code),
      ).or(
        where(salted_code_fingerprint: salted_fingerprints),
      ).find_by(user_id: user_id)
    end

    def scrypt_password_digest(password:, salt:, cost:)
      scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
      scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
      SCrypt::Password.new(scrypted).digest
    end

    private

    def create_fingerprint(code)
      Pii::Fingerprinter.fingerprint(code)
    end
  end
end
