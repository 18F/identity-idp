class Agreements::IaaStatus < ApplicationRecord
  self.table_name = 'iaa_statuses'

  has_many :iaa_gtcs, dependent: :restrict_with_exception
  has_many :iaa_orders, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :order, presence: true,
                    uniqueness: true,
                    numericality: { only_integer: true }
end
