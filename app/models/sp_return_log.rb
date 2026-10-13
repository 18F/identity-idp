# frozen_string_literal: true

# One handoff of a signed-in person to a service provider, or one delegated token issued for an
# agency API, as the unit invoicing counts. Rows are append-only: a later change to how a row is
# invoiced is recorded in SpReturnLogBillingAdjustment, never by updating the row.
class SpReturnLog < ApplicationRecord
  ACCESS_TYPE_DIRECT = 'direct'
  ACCESS_TYPE_DELEGATED = 'delegated'
  ACCESS_TYPES = [ACCESS_TYPE_DIRECT, ACCESS_TYPE_DELEGATED].freeze

  # rubocop:disable Rails/InverseOf
  belongs_to :user
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  belongs_to :profile_requested_service_provider,
             class_name: 'ServiceProvider',
             foreign_key: 'profile_requested_issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf
  has_many :billing_adjustments, class_name: 'SpReturnLogBillingAdjustment',
                                 inverse_of: :sp_return_log, dependent: nil

  validates :access_type, inclusion: { in: ACCESS_TYPES }, allow_nil: true

  def delegated?
    access_type == ACCESS_TYPE_DELEGATED
  end

  def excluded_from_billing?
    billing_adjustments.exclude_from_billing.exists?
  end
end
