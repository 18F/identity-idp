class Agreements::IaaGtc < ApplicationRecord
  self.table_name = 'iaa_gtcs'

  belongs_to :partner_account
  belongs_to :iaa_status

  has_many :iaa_orders, dependent: :restrict_with_exception
  has_many :integrations, through: :iaa_orders
  has_many :service_providers, through: :integrations

  validates :gtc_number, presence: true, uniqueness: true
  validates :mod_number,
            presence: true,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: 0 }
  validates :estimated_amount,
            numericality: { less_than: 10_000_000_000,
                            greater_than_or_equal_to: 0,
                            allow_nil: true }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  def status
    return 'pending_start' if Time.zone.today < start_date
    return 'expired' if Time.zone.today > end_date
    'active'
  end

  private

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?
    return unless end_date <= start_date

    errors.add(:end_date, 'must be after start date', type: :invalid_end_date)
  end
end
