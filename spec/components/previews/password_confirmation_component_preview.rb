class PasswordConfirmationComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display form true
  def default
    render(PasswordConfirmationComponent.new(form: form_builder))
  end
  # @!endgroup

  # @display form true
  # @param toggle_label text
  def workbench(toggle_label: nil)
    render(
      PasswordConfirmationComponent.new(
        form: form_builder,
        **{ toggle_label: }.compact,
      ),
    )
  end
end
