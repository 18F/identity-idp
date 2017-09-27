module FormFinanceValidator
  extend ActiveSupport::Concern

  VALID_BANK_ROUTING_LENGTH = 9

  VALID_CCN_LENGTH = 8

  VALID_MINIMUM_LENGTH = 8
  VALID_MAXIMUM_LENGTH = 30

  included do
    validates :finance_type,
              inclusion: {
                in: Idv::FinanceForm::FINANCE_TYPES,
                message: I18n.t('idv.errors.missing_finance'),
              }

    validates :bank_account_type,
              presence: true,
              inclusion: { in: %w[checking savings] },
              if: :bank_account?

    validates :bank_routing,
              presence: true,
              length: { is: VALID_BANK_ROUTING_LENGTH },
              format: { with: /\A\d+\z/ },
              if: :bank_account?

    validates :ccn,
              presence: true,
              length: { is: VALID_CCN_LENGTH },
              format: { with: /\A\d{8}\z/, message: I18n.t('idv.errors.invalid_ccn') },
              if: :ccn?

    (Idv::FinanceForm::FINANCE_TYPES - %i[ccn]).each do |finance_type|
      validates finance_type,
                presence: true,
                length: {
                  in: VALID_MINIMUM_LENGTH..VALID_MAXIMUM_LENGTH,
                  message: I18n.t(
                    'idv.errors.finance_number_length',
                    minimum: VALID_MINIMUM_LENGTH,
                    maximum: VALID_MAXIMUM_LENGTH
                  ),
                },
                format: { with: /\A\d+\z/ },
                if: "#{finance_type}?".to_sym
    end
  end
end
