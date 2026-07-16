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
      safe_join([button_content, success_icon_template]),
      'clipboard-text': clipboard_text,
      'tooltip-text': t('components.clipboard_button.tooltip'),
      class: css_class,
    )
  end

  def content
    return '' if icon_only?

    t('components.clipboard_button.label')
  end

  def css_class
    'clipboard-button--unstyled' if button_options[:unstyled]
  end

  def button_content
    render ButtonComponent.new(
      **button_tag_options,
      type: :button,
      icon: :copy,
    ).with_content(content)
  end

  def success_icon_template
    tag.template { render IconComponent.new(icon: :check_circle_filled) }
  end

  private

  def icon_only?
    button_options[:icon_only]
  end

  def button_tag_options
    opts = button_options.except(:unstyled, :icon_only)
    return opts unless icon_only?

    aria = opts.fetch(:aria, {}).to_h.transform_keys(&:to_sym)
    opts.merge(aria: aria.reverse_merge(label: t('components.clipboard_button.label')))
  end
end
