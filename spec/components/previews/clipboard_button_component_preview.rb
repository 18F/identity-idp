class ClipboardButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(ClipboardButtonComponent.new(clipboard_text: 'Copied Text'))
  end
  # @!endgroup

  # @param clipboard_text text
  def workbench(clipboard_text: 'Copied Text')
    render(ClipboardButtonComponent.new(clipboard_text: clipboard_text))
  end
end
