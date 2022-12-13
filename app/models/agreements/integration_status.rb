class Agreements::IntegrationStatus < ApplicationRecord
  self.table_name = 'integration_statuses'

  has_many :integrations, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :order,
            presence: true,
            uniqueness: true,
            numericality: { only_integer: true }
end
