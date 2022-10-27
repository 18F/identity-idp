class PasswordToggleComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(PasswordToggleComponent.new(form: form_builder))
  end
  # @!endgroup

  # @param label text
  # @param toggle_label text
  # @param toggle_position select [~,top,bottom]
  def workbench(label: nil, toggle_label: nil, toggle_position: 'top')
    render(
      PasswordToggleComponent.new(
        form: form_builder,
        **{ label: label, toggle_label: toggle_label }.compact,
        toggle_position: toggle_position.to_sym,
      ),
    )
  end
end
