class PivCacConfiguration < ApplicationRecord
  belongs_to :user, inverse_of: :piv_cac_configurations

  validates :user_id, presence: true
  validates :name, presence: true

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def mfa_enabled?
    user&.x509_dn_uuid.present?
  end

  def mfa_confirmed?(proposed_uuid)
    user && proposed_uuid && user.x509_dn_uuid == proposed_uuid
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::PivCacSelectionPresenter.new(self)]
    else
      []
    end
  end

  def friendly_name
    :piv_cac
  end

  def self.selection_presenters(set)
    set.flat_map(&:selection_presenters)
  end
end
