class Agreements::IaaOrder < ApplicationRecord
  self.table_name = 'iaa_orders'

  belongs_to :iaa_gtc
  belongs_to :iaa_status

  has_one :partner_account, through: :iaa_gtc
  has_many :integration_usages, dependent: :restrict_with_exception
  has_many :integrations, through: :integration_usages

  validates :order_number, presence: true,
                           uniqueness: { scope: :iaa_gtc_id },
                           numericality: { only_integer: true,
                                           greater_than_or_equal_to: 0 }
  validates :mod_number, presence: true,
                         numericality: { only_integer: true,
                                         greater_than_or_equal_to: 0 }
  validates :pricing_model, presence: true,
                            numericality: { only_integer: true,
                                            greater_than_or_equal_to: 0 }
  validates :estimated_amount, numericality: { less_than: 10_000_000_000,
                                               greater_than_or_equal_to: 0,
                                               allow_nil: true }
end
