# frozen_string_literal: true

class BadgeComponent < BaseComponent
  VARIANTS = {
    primary: 'ads-badge--primary',
    secondary: 'ads-badge--secondary',
    tertiary: 'ads-badge--tertiary',
    success: 'ads-badge--success',
    error: 'ads-badge--error',
    warning: 'ads-badge--warning',
  }.freeze

  ON_BACKGROUNDS = {
    light: 'ads-badge--on-light',
    dark: 'ads-badge--on-dark',
  }.freeze

  attr_reader :icon, :variant, :on_background, :tag_options

  def initialize(
    icon: nil,
    variant: :primary,
    on_background: :light,
    **tag_options
  )
    @icon = icon&.to_sym
    @variant = variant.to_sym
    @on_background = on_background.to_sym
    @tag_options = tag_options
  end

  def css_class
    classes = [
      'ads-badge',
      VARIANTS.fetch(variant),
      ON_BACKGROUNDS.fetch(on_background),
      *tag_options[:class],
    ]

    classes << 'ads-badge--icon-only' if icon_only?

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

    [content]
  end

  private

  def icon_only?
    icon.present? && content.blank?
  end
end
