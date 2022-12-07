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

# == Schema Information
#
# Table name: piv_cac_configurations
#
#  id           :bigint           not null, primary key
#  name         :string           not null
#  x509_dn_uuid :string           not null
#  x509_issuer  :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_piv_cac_configurations_on_user_id_and_created_at  (user_id,created_at) UNIQUE
#  index_piv_cac_configurations_on_user_id_and_name        (user_id,name) UNIQUE
#  index_piv_cac_configurations_on_x509_dn_uuid            (x509_dn_uuid) UNIQUE
#
