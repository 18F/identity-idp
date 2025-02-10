# frozen_string_literal: true

class ClipboardButtonComponent < BaseComponent
  attr_reader :clipboard_text, :button_options

  def initialize(clipboard_text:, **button_options)
    @clipboard_text = clipboard_text
    @button_options = button_options
  end

  def call
    content_tag(
      :'lg-clipboard-button',
      button_content,
      'clipboard-text': clipboard_text,
      'tooltip-text': t('components.clipboard_button.tooltip'),
      class: css_class,
    )
  end

  def content
    t('components.clipboard_button.label')
  end

  def css_class
    'clipboard-button--unstyled' if button_options[:unstyled]
  end

  def button_content
    render ButtonComponent.new(
      **button_options,
      type: :button,
      icon: :content_copy,
    ).with_content(content)
  end
end
