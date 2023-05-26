class ClipboardButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(ClipboardButtonComponent.new(clipboard_text: 'Copied Text', class: css_class))
  end

  def unstyled
    render(
      ClipboardButtonComponent.new(clipboard_text: 'Copied Text', unstyled: true, class: css_class),
    )
  end
  # @!endgroup

  # @param clipboard_text text
  # @param unstyled toggle
  def workbench(clipboard_text: 'Copied Text', unstyled: false)
    render(ClipboardButtonComponent.new(clipboard_text:, unstyled:, class: css_class))
  end

  private

  def css_class
    'margin-top-4'
  end
end
