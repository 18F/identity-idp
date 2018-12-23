class BackupCodeConfiguration < ApplicationRecord
  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :code)

  include BackupCodeEncryptedAttributeOverrides

  belongs_to :user

  def self.unused
    where(used_at: nil)
  end

  def mfa_enabled?
    Event.find_by(user_id: user&.id, event_type: :backup_codes_added)
  end

  # This method smells of :reek:UtilityFunction
  def selection_presenters
    [TwoFactorAuthentication::BackupCodeSelectionPresenter.new]
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
      code_fingerprint = create_fingerprint(code)
      find_by(code_fingerprint: code_fingerprint, user_id: user_id)
    end

    private

    def create_fingerprint(code)
      Pii::Fingerprinter.fingerprint(code)
    end
  end
end
