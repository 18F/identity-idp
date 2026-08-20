# frozen_string_literal: true

class ButtonComponent < BaseComponent
  # Legacy/control A/B bucket rendering. Output is byte-identical to
  # origin/main: variant:/size: are ignored, the boolean API is honored, and
  # parts keep the [icon_content, content] ordering. This is the control arm of
  # the NDS experiment; when the experiment ends this logic inlines back into
  # ButtonComponent and NdsStyle is deleted.
  class LegacyStyle
    def css_class(component)
      classes = ['usa-button', *component.tag_options[:class]]
      classes << 'usa-button--big' if component.big
      classes << 'usa-button--wide' if component.wide
      classes << 'usa-button--full-width' if component.full_width
      classes << 'usa-button--outline' if component.outline
      classes << 'usa-button--unstyled' if component.unstyled
      classes << 'usa-button--danger' if component.danger
      classes
    end

    def parts(component)
      [component.icon_content, component.content]
    end
  end
end
