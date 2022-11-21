class PasswordToggleComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(PasswordToggleComponent.new(form: form_builder))
  end
  # @!endgroup

  # @param label text
  # @param toggle_label text
  def workbench(label: nil, toggle_label: nil)
    render(
      PasswordToggleComponent.new(
        form: form_builder,
        **{ toggle_label: toggle_label }.compact,
        field_options: { label: label }.compact,
      ),
    )
  end
end
