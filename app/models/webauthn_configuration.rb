class WebauthnConfiguration < ApplicationRecord
  belongs_to :user
  validates :name, presence: true
  validates :credential_id, presence: true
  validates :credential_public_key, presence: true

  def mfa_enabled?
    true
  end

  def selection_presenters
    [TwoFactorAuthentication::WebauthnSelectionPresenter.new(self)]
  end

  def friendly_name
    :webauthn
  end

  def self.selection_presenters(set)
    set.any? ? set.first.selection_presenters : []
  end
end
