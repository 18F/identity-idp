class ToastComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param message text
  # @param show_delay number
  # @param dismiss_after number
  def workbench(
    message: 'Toast message',
    show_delay: 500,
    dismiss_after: 3000
  )
    render(
      ToastComponent.new(
        message:,
        show_delay: show_delay.to_i,
        dismiss_after: dismiss_after.to_i,
      ),
    )
  end

  # @display body_class "padding-0"
  def trigger
    render_with_template
  end
end
