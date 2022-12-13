class Agreements::Integration < ApplicationRecord
  self.table_name = 'integrations'

  belongs_to :partner_account
  belongs_to :integration_status
  belongs_to :service_provider

  has_many :integration_usages, dependent: :restrict_with_exception
  has_many :iaa_orders, through: :integration_usages

  validates :issuer, presence: true, uniqueness: true
  validates :name, presence: true
  validates :dashboard_identifier,
            uniqueness: { allow_nil: true },
            numericality: { only_integer: true,
                            greater_than: 0,
                            allow_nil: true }
end
