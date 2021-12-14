class ClipboardButtonComponent < ButtonComponent
  attr_reader :clipboard_text, :tag_options

  def initialize(clipboard_text:, **tag_options)
    super(**tag_options)

    @clipboard_text = clipboard_text
    @tag_options = tag_options
  end

  def call
    content_tag(:'lg-clipboard-button', super, data: { clipboard_text: clipboard_text })
  end
end
