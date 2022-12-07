class Agreements::Integration < ApplicationRecord
  self.table_name = 'integrations'

  belongs_to :partner_account
  belongs_to :integration_status
  belongs_to :service_provider

  has_many :integration_usages, dependent: :restrict_with_exception
  has_many :iaa_orders, through: :integration_usages

  validates :issuer, presence: true, uniqueness: true
  validates :name, presence: true
  validates :dashboard_identifier, uniqueness: { allow_nil: true },
                                   numericality: { only_integer: true,
                                                   greater_than: 0,
                                                   allow_nil: true }
end

# == Schema Information
#
# Table name: integrations
#
#  id                    :bigint           not null, primary key
#  dashboard_identifier  :integer
#  issuer                :string           not null
#  name                  :string           not null
#  integration_status_id :bigint
#  partner_account_id    :bigint
#  service_provider_id   :bigint
#
# Indexes
#
#  index_integrations_on_dashboard_identifier   (dashboard_identifier) UNIQUE
#  index_integrations_on_integration_status_id  (integration_status_id)
#  index_integrations_on_issuer                 (issuer) UNIQUE
#  index_integrations_on_partner_account_id     (partner_account_id)
#  index_integrations_on_service_provider_id    (service_provider_id)
#
# Foreign Keys
#
#  fk_rails_...  (integration_status_id => integration_statuses.id)
#  fk_rails_...  (partner_account_id => partner_accounts.id)
#  fk_rails_...  (service_provider_id => service_providers.id)
#
