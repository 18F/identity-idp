module Idv
  class FinanceForm
    include ActiveModel::Model
    include FormFinanceValidator

    FINANCE_TYPES = [:ccn, :mortgage, :home_equity_line, :auto_loan].freeze

    FINANCE_HTML_OPTIONS = {
      ccn: { maxlength: 8 },
      mortgage: { minlength: 8 },
      home_equity_line: { minlength: 8 },
      auto_loan: { minlength: 8 }
    }.freeze

    attr_reader :idv_params, :finance_type, *FINANCE_TYPES

    def initialize(idv_params)
      @idv_params = idv_params
      finance_type = FINANCE_TYPES.find { |param| idv_params.key? param }
      update_finance_values(idv_params.merge(finance_type: finance_type))
    end

    def submit(params)
      @params = params
      finance_value = update_finance_values(params)
      return false unless valid?

      clear_idv_params_finance
      idv_params[finance_type] = finance_value
      true
    end

    def self.finance_type_choices
      FINANCE_TYPES.map { |choice| [choice, I18n.t("idv.form.#{choice}")] }
    end

    def self.finance_type_inputs
      FINANCE_TYPES.map do |choice|
        [choice, I18n.t("idv.form.#{choice}"), FINANCE_HTML_OPTIONS.fetch(choice, {})]
      end
    end

    private

    attr_writer :finance_type, *FINANCE_TYPES

    def update_finance_values(params)
      type = params[:finance_type]
      return false unless valid_finance_type?(type)

      self.finance_type = type.to_sym
      send("#{finance_type}=", params[finance_type])
    end

    def clear_idv_params_finance
      FINANCE_TYPES.each do |finance_param|
        idv_params.delete(finance_param)
      end
    end
  end
end
