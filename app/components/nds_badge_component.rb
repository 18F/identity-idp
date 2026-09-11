# frozen_string_literal: true

# NDS badge. Renders a <span class="badge badge--<variant>"> with an optional
# icon and content. Instantiated by BadgeComponent when a render resolves to
# the NDS bucket; call sites always use BadgeComponent directly.
class NDSBadgeComponent < BadgeComponent
  VARIANTS = {
    primary: 'badge--primary',
    secondary: 'badge--secondary',
    tertiary: 'badge--tertiary',
    success: 'badge--success',
    error: 'badge--error',
    warning: 'badge--warning',
    info: 'badge--info',
  }.freeze

  def css_class
    classes = ['badge', VARIANTS.fetch(variant), *tag_options[:class]]
    classes << 'badge--icon-only' if icon_only?
    classes
  end

  def parts
    return [icon_content] if icon_only?

    [content]
  end

  def icon_content
    render IconComponent.new(icon:) if icon
  end

  private

  def icon_only?
    icon.present? && content.blank?
  end
end
