class AuthAppConfiguration < ApplicationRecord
  include EncryptableAttribute

  encrypted_attribute(name: :otp_secret_key)

  belongs_to :user

  validates :name, presence: true

  def mfa_enabled?
    otp_secret_key.present?
  end

  def selection_presenters
    mfa_enabled? ? [TwoFactorAuthentication::AuthAppSelectionPresenter.new(self)] : []
  end

  def friendly_name
    :auth_app
  end

  def self.selection_presenters(set)
    set.any? ? set.first.selection_presenters : []
  end
end
