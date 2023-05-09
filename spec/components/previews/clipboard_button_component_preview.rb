class ClipboardButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(ClipboardButtonComponent.new(clipboard_text: 'Copied Text', class: css_class))
  end
  # @!endgroup

  # @param clipboard_text text
  def workbench(clipboard_text: 'Copied Text')
    render(ClipboardButtonComponent.new(clipboard_text:, class: css_class))
  end

  private

  def css_class
    'margin-top-4'
  end
end
