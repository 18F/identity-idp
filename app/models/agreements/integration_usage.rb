class Agreements::IntegrationUsage < ApplicationRecord
  self.table_name = 'integration_usages'

  belongs_to :iaa_order, -> { includes(iaa_gtc: :partner_account) },
             inverse_of: :integration_usages
  belongs_to :integration, -> { includes(:partner_account) },
             inverse_of: :integration_usages

  has_one :partner_account, through: :integration

  validates :iaa_order, presence: true
  validates :integration, presence: true
  validates :integration_id, uniqueness: { scope: :iaa_order_id }

  # DISABLED 2021-10-20 due to unforeseen edge case where we transfer an
  # integration from one account to another
  # validate :integration_and_order_have_same_account

  private

  def integration_and_order_have_same_account
    return unless integration.present? && iaa_order.present?
    return if integration.partner_account == iaa_order.partner_account

    errors.add(
      :iaa_order, 'must belong to same partner account as integration',
      type: :partner_account_does_match_integration
    )
  end
end
