class PasswordToggleComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(PasswordToggleComponent.new(form: form_builder))
  end
  # @!endgroup

  # @param label text
  def workbench(label: nil)
    render(
      PasswordToggleComponent.new(
        form: form_builder,
        field_options: { label: label }.compact,
      ),
    )
  end
end
