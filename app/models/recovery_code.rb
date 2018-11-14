class RecoveryCode < ApplicationRecord
  #self.ignored_columns = %w(encrypted_code)

  belongs_to :user

  #include EncryptableAttribute
  #encrypted_attribute(name: :code)

  #include RecoveryCodeEncryptedAttributeOverrides

  def mfa_enabled?
    true
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::AuthAppSelectionPresenter.new(self)]
    else
      []
    end
  end

  def friendly_name
    :recovery_codes
  end

  def self.selection_presenters(set)
    set.flat_map(&:selection_presenters)
  end
end
