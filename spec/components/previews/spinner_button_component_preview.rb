class SpinnerButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(SpinnerButtonComponent.new(big: true).with_content('Submit'))
  end

  def action_message
    render(
      SpinnerButtonComponent.new(
        big: true,
        action_message: 'Verifying…',
      ).with_content('Submit'),
    )
  end
  # @!endgroup

  # @display form true
  # @param action_message text
  def workbench(action_message: nil)
    render(
      SpinnerButtonComponent.new(
        form: form_builder,
        big: true,
        **{ action_message: }.compact,
      ).with_content('Submit'),
    )
  end
end
