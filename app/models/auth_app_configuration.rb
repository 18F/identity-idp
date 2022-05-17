class AuthAppConfiguration < ApplicationRecord
  include EncryptableAttribute

  encrypted_attribute(name: :otp_secret_key)

  belongs_to :user

  validates :name, presence: true

  def mfa_enabled?
    otp_secret_key.present?
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::AuthAppSelectionPresenter.new(configuration: self)]
    else
      []
    end
  end

  def friendly_name
    :auth_app
  end

  def self.selection_presenters(set)
    if set.any?
      set.first.selection_presenters
    else
      []
    end
  end
end
