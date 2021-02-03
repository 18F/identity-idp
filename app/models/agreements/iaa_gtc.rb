class Agreements::IaaGtc < ApplicationRecord
  self.table_name = 'iaa_gtcs'

  belongs_to :partner_account
  belongs_to :iaa_status

  has_many :iaa_orders, dependent: :restrict_with_exception

  validates :gtc_number, presence: true, uniqueness: true
  validates :mod_number, presence: true,
                         numericality: { only_integer: true,
                                         greater_than_or_equal_to: 0 }
  validates :estimated_amount, numericality: { less_than: 10_000_000_000,
                                               greater_than_or_equal_to: 0,
                                               allow_nil: true }
end
