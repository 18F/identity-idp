# frozen_string_literal: true

class ButtonComponent < BaseComponent
  VARIANTS = {
    primary: 'ads-button--primary',
    secondary: 'ads-button--secondary',
    tertiary: 'ads-button--tertiary',
    quaternary: 'ads-button--quaternary',
    ghost: 'ads-button--ghost',
    destructive: 'ads-button--destructive',
  }.freeze

  SIZES = {
    lg: 'ads-button--lg',
    md: 'ads-button--md',
    sm: 'ads-button--sm',
  }.freeze

  attr_reader :url, :method, :icon, :icon_position, :size, :variant, :tag_options

  def initialize(
    url: nil,
    method: nil,
    icon: nil,
    icon_position: :left,
    size: :lg,
    variant: :primary,
    **tag_options
  )
    @url = url
    @method = method
    @icon = icon
    @icon_position = icon_position.to_sym
    @size = size.to_sym
    @variant = variant.to_sym
    @tag_options = tag_options
  end

  def css_class
    classes = [
      'ads-button',
      VARIANTS.fetch(variant),
      SIZES.fetch(size),
      *tag_options[:class],
    ]

    if icon
      classes << (icon_only? ? 'ads-button--icon-only' : icon_position_class)
    end

    classes
  end

  def icon_content
    render IconComponent.new(icon:) if icon
  end

  def content
    original_content = super
    return original_content if original_content.blank? || icon.blank?

    trimmed_content = original_content.lstrip
    trimmed_content = sanitize(trimmed_content) if original_content.html_safe?
    trimmed_content
  end

  def parts
    return [icon_content] if icon_only?

    icon_position == :right ? [content, icon_content] : [icon_content, content]
  end

  private

  def icon_only?
    icon.present? && content.blank?
  end

  def icon_position_class
    icon_position == :right ? 'ads-button--icon-right' : 'ads-button--icon-left'
  end

  def action
    @action ||= begin
      if url
        if method && method != :get
          lambda do |**tag_options, &block|
            form_class = ['ads-form__button-wrapper', *tag_options[:form_class]]
            button_options = tag_options.except(:form_class)
            button_to(url, method:, **button_options, form_class:, &block)
          end
        else
          ->(**tag_options, &block) { link_to(url, **tag_options, &block) }
        end
      else
        ->(**tag_options, &block) { button_tag(**tag_options, &block) }
      end
    end
  end
end
