module Idv
  class FinanceForm
    include ActiveModel::Model

    FINANCE_TYPES = [:ccn, :mortgage, :home_equity_line, :auto_loan].freeze

    FINANCE_HTML_OPTIONS = {
      ccn: { maxlength: 8 }
    }.freeze

    attr_reader :idv_params, :finance_type, *FINANCE_TYPES

    validates :finance_type, presence: true

    FINANCE_TYPES.each do |type|
      validates type, presence: true, if: ->(form) { form.finance_type == type }
    end

    validates :ccn,
              format: { with: /\A\d{8}\z/, message: I18n.t('idv.errors.invalid_ccn') },
              if: :ccn?

    validate :validate_finance_type

    def initialize(idv_params)
      @idv_params = idv_params
      finance_type = FINANCE_TYPES.find { |param| idv_params.key? param }
      update_finance_values(idv_params.merge(finance_type: finance_type))
    end

    def submit(params)
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

    def ccn?
      finance_type == :ccn
    end

    def validate_finance_type
      return if valid_finance_type?(finance_type)

      errors.add :finance_type, I18n.t('idv.errors.missing_finance')
    end

    def valid_finance_type?(type)
      type.present? && FINANCE_TYPES.include?(type.to_sym)
    end

    def update_finance_values(params)
      type = params[:finance_type]
      return false unless valid_finance_type?(type)

      self.finance_type = type.to_sym
      send("#{finance_type}=", params[finance_type])
    end

    def clear_idv_params_finance
      FINANCE_TYPES.each do |f_param|
        idv_params.delete f_param
      end
    end
  end
end
