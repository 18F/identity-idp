# frozen_string_literal: true

class PivCacConfiguration < ApplicationRecord
  include UserSuppliedNameAttributes

  belongs_to :user
  validates :name, presence: true, length: { maximum: UserSuppliedNameAttributes::MAX_NAME_LENGTH }

  def mfa_enabled?
    x509_dn_uuid.present?
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::SignInPivCacSelectionPresenter.new(user:, configuration: self)]
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
