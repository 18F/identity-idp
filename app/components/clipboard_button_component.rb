class ClipboardButtonComponent < ButtonComponent
  attr_reader :clipboard_text, :tag_options

  def initialize(clipboard_text:, **tag_options)
    super(**tag_options, icon: :content_copy)

    @clipboard_text = clipboard_text
  end

  def call
    content_tag(:'lg-clipboard-button', super, data: { clipboard_text: clipboard_text })
  end

  def content
    t('links.copy')
  end
end
