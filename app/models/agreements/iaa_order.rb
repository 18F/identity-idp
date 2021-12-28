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
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  def status
    return 'pending_start' if Time.zone.today < start_date
    return 'expired' if Time.zone.today > end_date
    'active'
  end

  def in_pop?(date)
    raise ArgumentError unless date.respond_to?(:strftime)
    return false if pop_range.blank?

    pop_range.include?(date.to_date)
  end

  private

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?
    return unless end_date <= start_date

    errors.add(:end_date, 'must be after start date', type: :invalid_end_date)
  end

  def pop_range
    return unless start_date.present? && end_date.present?

    start_date..end_date
  end
end
