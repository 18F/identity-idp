class ClipboardButtonComponent < ButtonComponent
  attr_reader :clipboard_text, :tag_options

  def initialize(clipboard_text:, **tag_options)
    super(**tag_options, type: :button, icon: :content_copy)

    @clipboard_text = clipboard_text
  end

  def call
    content_tag(
      :'lg-clipboard-button',
      super,
      'clipboard-text': clipboard_text,
      'tooltip-text': t('components.clipboard_button.tooltip'),
    )
  end

  def content
    t('components.clipboard_button.label')
  end
end
