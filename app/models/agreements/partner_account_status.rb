class Agreements::PartnerAccountStatus < ApplicationRecord
  self.table_name = 'partner_account_statuses'

  has_many :partner_accounts, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :order,
            presence: true,
            uniqueness: true,
            numericality: { only_integer: true }

  def partner_name
    super || name
  end
end
