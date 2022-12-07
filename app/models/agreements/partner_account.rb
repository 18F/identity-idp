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

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: partner_accounts
#
#  id                        :bigint           not null, primary key
#  became_partner            :date
#  description               :text
#  name                      :string           not null
#  requesting_agency         :string           not null
#  agency_id                 :bigint
#  crm_id                    :bigint
#  partner_account_status_id :bigint
#
# Indexes
#
#  index_partner_accounts_on_agency_id                  (agency_id)
#  index_partner_accounts_on_name                       (name) UNIQUE
#  index_partner_accounts_on_partner_account_status_id  (partner_account_status_id)
#  index_partner_accounts_on_requesting_agency          (requesting_agency) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (agency_id => agencies.id)
#  fk_rails_...  (partner_account_status_id => partner_account_statuses.id)
#
# rubocop:enable Layout/LineLength
