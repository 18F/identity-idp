module Idv
  class FinanceForm
    include ActiveModel::Model

    BANK_ACCOUNT_FINANCE_TYPES = %w[bank_account ccn].freeze
    OTHER_FINANCE_TYPES = %w[mortgage home_equity_line auto_loan].freeze

    FINANCE_TYPES = BANK_ACCOUNT_FINANCE_TYPES + OTHER_FINANCE_TYPES
    FINANCE_VALUES = FINANCE_TYPES + %w[bank_routing bank_account_type]

    include FormFinanceValidator

    attr_accessor :finance_type, *FINANCE_VALUES

    def initialize(params = {})
      assign_finance_type(params)
      assign_finance_values(params)
    end

    def submit(params)
      clear_finance_values

      self.finance_type = params[:finance_type]
      assign_finance_values(params)

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    # Defines bank_account?, #ccn?, auto_loan?, etc
    FINANCE_TYPES.each do |finance_type|
      define_method("#{finance_type}?") do
        self.finance_type == finance_type
      end
    end

    def idv_params
      return unless FINANCE_TYPES.include?(finance_type)
      return bank_account_idv_params if bank_account?
      { finance_type.to_sym => send(finance_type) }
    end

    private

    def assign_finance_type(params)
      finance_type_key = params.keys.find { |key| FINANCE_TYPES.include?(key.to_s) }
      self.finance_type = finance_type_key.to_s if finance_type_key.present?
    end

    def assign_finance_values(params)
      params.each do |key, value|
        send("#{key}=", value) if FINANCE_VALUES.include?(key.to_s)
      end
    end

    def bank_account_idv_params
      {
        bank_account: bank_account,
        bank_routing: bank_routing,
        bank_account_type: bank_account_type,
      }
    end

    def clear_finance_values
      FINANCE_VALUES.each do |finance_value|
        send("#{finance_value}=", nil)
      end
    end
  end
end
