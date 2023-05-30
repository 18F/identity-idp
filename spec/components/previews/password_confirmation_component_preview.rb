class PasswordConfirmationComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display form true
  def default
    render(PasswordConfirmationComponent.new(form: form_builder))
  end
  # @!endgroup

  # @display form true
  def workbench
    render(PasswordConfirmationComponent.new(form: form_builder))
  end
end
