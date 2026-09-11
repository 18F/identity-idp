# frozen_string_literal: true

# NDS A/B bucket button. Honors gsa-staging's variant:/size:/icon_position: API,
# emitted on standard USWDS `.usa-button` selectors so Path 4's nds overlay
# styles them. Rendered by ButtonComponent (the caller-facing entry point) when
# the render resolves to the NDS bucket; not instantiated by call sites
# directly. Deleting this file + the delegation branch in ButtonComponent tears
# the experiment down cleanly.
class NDSButtonComponent < ButtonComponent
  VARIANTS = {
    primary: nil,
    secondary: 'usa-button--secondary',
    tertiary: 'usa-button--tertiary',
    quaternary: 'usa-button--quaternary',
    ghost: 'usa-button--ghost',
    destructive: 'usa-button--danger',
  }.freeze

  SIZES = {
    lg: 'usa-button--lg',
    md: 'usa-button--md',
    sm: 'usa-button--sm',
  }.freeze

  def css_class
    classes = [
      'usa-button',
      VARIANTS.fetch(variant),
      SIZES.fetch(size),
      *tag_options[:class],
    ].compact

    classes << (icon_only? ? 'usa-button--icon-only' : icon_position_class) if icon

    classes
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
    icon_position == :right ? 'usa-button--icon-right' : 'usa-button--icon-left'
  end
end
