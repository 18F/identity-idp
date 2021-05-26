class PivCacConfiguration < ApplicationRecord
  belongs_to :user

  validates :name, presence: true

  def mfa_enabled?
    x509_dn_uuid.present?
  end

  def selection_presenters
    mfa_enabled? ? [TwoFactorAuthentication::PivCacSelectionPresenter.new(self)] : []
  end

  def friendly_name
    :piv_cac
  end

  def self.selection_presenters(set)
    set.any? ? set.first.selection_presenters : []
  end
end
