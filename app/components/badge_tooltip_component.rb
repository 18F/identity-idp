# frozen_string_literal: true

class BadgeTooltipComponent < BaseComponent
  attr_reader :tooltip_text, :icon, :tag_options

  def initialize(tooltip_text:, icon:, **tag_options)
    @tooltip_text = tooltip_text
    @icon = icon
    @tag_options = tag_options
  end

  def call
    content_tag(:span, badge_content, **tag_options, class: ['badge-tooltip', *tag_options[:class]])
  end

  def badge_content
    render(
      BadgeComponent.new(icon:, class: 'usa-tooltip', title: tooltip_text).with_content(content),
    )
  end
end
