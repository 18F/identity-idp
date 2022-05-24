class PivCacConfiguration < ApplicationRecord
  belongs_to :user

  validates :name, presence: true

  def mfa_enabled?
    x509_dn_uuid.present?
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::PivCacSelectionPresenter.new(configuration: self)]
    else
      []
    end
  end

  def friendly_name
    :piv_cac
  end

  def self.selection_presenters(set)
    if set.any?
      set.first.selection_presenters
    else
      []
    end
  end
end
