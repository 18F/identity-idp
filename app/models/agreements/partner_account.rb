# frozen_string_literal: true

class Agreements::PartnerAccount < ApplicationRecord
  self.table_name = 'partner_accounts'

  belongs_to :agency
  belongs_to :partner_account_status

  has_many :iaa_gtcs, dependent: :restrict_with_exception
  has_many :iaa_orders, through: :iaa_gtcs
  has_many :integrations, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :requesting_agency, presence: true, uniqueness: true

  def partner_status
    partner_account_status.partner_name
  end
end
