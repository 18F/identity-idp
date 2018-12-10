class BackupCodeConfiguration < ApplicationRecord
  include EncryptableAttribute

  devise(
  )

  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :code)

  # IMPORTANT this comes *after* devise() call.
  include BackupCodeEncryptedAttributeOverrides

  belongs_to :user

  def self.unused
    where(used: false)
  end

  def mfa_enabled?
    used == false
  end

  # This method smells of :reek:UtilityFunction
  def selection_presenters
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new]
  end

  def friendly_name
    :backup_codes
  end

  def code=(code)
    set_encrypted_attribute(name: :code, value: code)
    self.code_fingerprint = code.present? ? encrypted_attributes[:code].fingerprint : ''
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
      return nil if !code.is_a?(String) || code.empty?
      code = code.downcase.strip
      code_fingerprint = create_fingerprint(code)
      find_by(code_fingerprint: code_fingerprint, user_id: user_id)
    end

    private

    def create_fingerprint(code)
      Pii::Fingerprinter.fingerprint(code)
    end
  end
end
