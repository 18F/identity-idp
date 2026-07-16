class AlertComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param message text
  # @param title text
  # @param type select [neutral, warning, error]
  # @param dismissible toggle
  # @param action_label text
  # @param action_url text
  def workbench(
    message: 'This is an example of a dismissible message in the experience for users to see.',
    title: nil,
    type: :neutral,
    dismissible: true,
    action_label: nil,
    action_url: nil
  )
    action = if action_label.present? || action_url.present?
               { label: action_label.presence, url: action_url.presence }
             end

    render(
      AlertComponent.new(
        type: type.to_sym,
        title: title.presence,
        message:,
        dismissible:,
        action:,
      ),
    )
  end
end
