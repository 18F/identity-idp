FinanceFormDecorator = Struct.new(:idv_params) do
  def label_text
    I18n.t("idv.form.#{finance_type}")
  end

  private

  def finance_type
    finance_types.find { |ft| ft == idv_params[ft] } || 'finance_unselected'
  end

  def finance_types
    Idv::FinanceForm::FINANCE_TYPES
  end
end
