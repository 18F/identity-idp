module Idv
  class FinanceForm
    include ActiveModel::Model

    FINANCE_TYPES = [:ccn, :mortgage, :home_equity_line, :auto_loan].freeze

    attr_reader :idv_params, :finance_type, :finance_account

    validates :finance_type, :finance_account, presence: true

    validates :finance_account,
              format: { with: /\A\d{8}\z/, message: I18n.t('idv.errors.invalid_ccn') },
              if: :ccn?

    validate :finance_type_valid

    def initialize(idv_params)
      @idv_params = idv_params
      self.finance_type = FINANCE_TYPES.find { |param| idv_params.key? param }
      self.finance_account = idv_params[finance_type]
    end

    def submit(params)
      self.finance_type = params[:finance_type]
      self.finance_account = params[:finance_account]
      return false unless valid?
      clear_idv_params_finance
      idv_params[finance_type.to_sym] = finance_account
      true
    end

    def self.finance_type_choices
      FINANCE_TYPES.map { |choice| [choice, I18n.t("idv.form.#{choice}")] }
    end

    private

    attr_writer :finance_type, :finance_account

    def ccn?
      finance_type == :ccn
    end

    def finance_type_valid
      return if finance_type.present? && FINANCE_TYPES.include?(finance_type.to_sym)

      errors.add :finance_type, I18n.t('idv.errors.missing_finance')
    end

    def clear_idv_params_finance
      FINANCE_TYPES.each do |f_param|
        idv_params.delete f_param
      end
    end
  end
end
