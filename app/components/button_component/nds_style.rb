# frozen_string_literal: true

class ButtonComponent < BaseComponent
  # NDS A/B bucket rendering. Honors gsa-staging's variant:/size:/icon_position:
  # API, emitted on standard USWDS `.usa-button` selectors so Path 4's nds
  # overlay styles them and the look can backport to USWDS. primary = base
  # `.usa-button` (no modifier); destructive reuses the existing `--danger`
  # modifier (bucket-differentiated by CSS). Deleting this file (and the
  # NdsStyle branch in ButtonComponent#style) tears the experiment down cleanly.
  class NdsStyle
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

    def css_class(component)
      classes = [
        'usa-button',
        VARIANTS.fetch(component.variant),
        SIZES.fetch(component.size),
        *component.tag_options[:class],
      ].compact

      if component.icon
        modifier = icon_only?(component) ? 'usa-button--icon-only' : icon_position_class(component)
        classes << modifier
      end

      classes
    end

    def parts(component)
      return [component.icon_content] if icon_only?(component)

      if component.icon_position == :right
        [component.content, component.icon_content]
      else
        [component.icon_content, component.content]
      end
    end

    private

    def icon_only?(component)
      component.icon.present? && component.content.blank?
    end

    def icon_position_class(component)
      component.icon_position == :right ? 'usa-button--icon-right' : 'usa-button--icon-left'
    end
  end
end
