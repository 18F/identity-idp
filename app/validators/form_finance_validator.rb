module FormFinanceValidator
  extend ActiveSupport::Concern

  VALID_MINIMUM_LENGTH = 8
  VALID_MAXIMUM_LENGTH = 30

  included do
    attr_reader :params

    validates :finance_type, presence: true

    validates(
      :ccn,
      format: { with: /\A\d{8}\z/, message: I18n.t('idv.errors.invalid_ccn') },
      if: :ccn?
    )

    validate :validate_finance_type
    validate :validate_finance_value_presence
    validate :validate_finance_value_length, if: :not_ccn?
  end

  private

  def ccn?
    finance_type == :ccn
  end

  def not_ccn?
    !ccn?
  end

  def validate_finance_type
    return if valid_finance_type?(finance_type)
    errors.add :finance_type, I18n.t('idv.errors.missing_finance')
  end

  def valid_finance_type?(type)
    type.present? && Idv::FinanceForm::FINANCE_TYPES.include?(type.to_sym)
  end

  def validate_finance_value_presence
    return unless valid_finance_type?(finance_type)
    return if finance_value.present?
    errors.add finance_type, I18n.t('errors.messages.blank')
  end

  def validate_finance_value_length
    return if finance_value.blank?
    return if valid_range.include?(finance_value.length)
    errors.add(
      finance_type,
      I18n.t(
        'idv.errors.finance_number_length',
        minimum: VALID_MINIMUM_LENGTH,
        maximum: VALID_MAXIMUM_LENGTH
      )
    )
  end

  def finance_value
    params[finance_type]
  end

  def valid_range
    VALID_MINIMUM_LENGTH..VALID_MAXIMUM_LENGTH
  end
end
