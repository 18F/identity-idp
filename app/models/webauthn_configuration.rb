class WebauthnConfiguration < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true
  validates :name, presence: true
  validates :credential_id, presence: true
  validates :credential_public_key, presence: true

  # :reek:UtilityFunction
  def mfa_enabled?
    FeatureManagement.webauthn_enabled?
  end

  def selection_presenters
    [TwoFactorAuthentication::WebauthnSelectionPresenter.new(self)]
  end

  def friendly_name
    :webauthn
  end
end
