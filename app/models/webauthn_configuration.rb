class WebauthnConfiguration < ApplicationRecord
  belongs_to :user
  validates :name, presence: true
  validates :credential_id, presence: true
  validates :credential_public_key, presence: true

  def self.roaming_authenticators
    self.where(platform_authenticator: [nil, false])
  end

  def self.platform_authenticators
    self.where(platform_authenticator: true)
  end

  def mfa_enabled?
    true
  end

  def selection_presenters
    if platform_authenticator?
      [TwoFactorAuthentication::WebauthnPlatformSelectionPresenter.new(configuration: self)]
    else
      [TwoFactorAuthentication::WebauthnSelectionPresenter.new(configuration: self)]
    end
  end

  def friendly_name
    if platform_authenticator?
      :webauthn_platform
    else
      :webauthn
    end
  end

  def self.selection_presenters(set)
    if set.any?
      set.map(&:selection_presenters).flatten.uniq(&:class)
    else
      []
    end
  end
end
