class BackupCodeConfiguration < ApplicationRecord
  NUM_WORDS = 3

  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :code)

  include BackupCodeEncryptedAttributeOverrides

  belongs_to :user

  def self.unused
    where(used_at: nil)
  end

  def mfa_enabled?
    persisted? && used_at.nil?
  end

  def selection_presenters
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new(configuration: self)]
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
      code = RandomPhrase.normalize(code)

      user_salt_costs = select(:code_salt, :code_cost).
        distinct.
        where(user_id: user_id).
        where.not(code_salt: nil).where.not(code_cost: nil).
        pluck(:code_salt, :code_cost)

      salted_fingerprints = user_salt_costs.map do |salt, cost|
        scrypt_password_digest(password: code, salt: salt, cost: cost)
      end

      where(salted_code_fingerprint: salted_fingerprints).find_by(user_id: user_id)
    end

    def scrypt_password_digest(password:, salt:, cost:)
      scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
      scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
      SCrypt::Password.new(scrypted).digest
    end
  end
end

# == Schema Information
#
# Table name: backup_code_configurations
#
#  id                      :bigint           not null, primary key
#  code_cost               :string
#  code_salt               :string
#  salted_code_fingerprint :string
#  used_at                 :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :integer          not null
#
# Indexes
#
#  index_backup_code_configurations_on_user_id_and_created_at  (user_id,created_at)
#  index_backup_codes_on_user_id_and_salted_code_fingerprint   (user_id,salted_code_fingerprint)
#
