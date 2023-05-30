class OneTimeCodeInputComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display form true
  def numeric
    render(OneTimeCodeInputComponent.new(form: form_builder))
  end

  def alphanumeric
    render(OneTimeCodeInputComponent.new(form: form_builder, numeric: false))
  end

  def with_optional_prefix
    render(OneTimeCodeInputComponent.new(form: form_builder, numeric: false, optional_prefix: '#'))
  end
  # @!endgroup

  # @display form true
  # @param numeric toggle
  # @param optional_prefix text
  def workbench(numeric: true, optional_prefix: '')
    render(OneTimeCodeInputComponent.new(form: form_builder, numeric:, optional_prefix:))
  end
end
