class OneTimeCodeInputComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display form true
  def numeric
    render(OneTimeCodeInputComponent.new(form: form_builder))
  end

  def alphanumeric
    render(OneTimeCodeInputComponent.new(form: form_builder, numeric: false))
  end
  # @!endgroup

  # @display form true
  # @param numeric toggle
  def workbench(numeric: true)
    render(OneTimeCodeInputComponent.new(form: form_builder, numeric: numeric))
  end
end
