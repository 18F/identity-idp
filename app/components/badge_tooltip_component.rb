# frozen_string_literal: true

class BadgeTooltipComponent < BaseComponent
  attr_reader :tag_options, :tooltip_text

  def initialize(tooltip_text:, **tag_options)
    @tag_options = tag_options
    @tooltip_text = tooltip_text
  end

  def call
    content_tag(
      :'lg-badge-tooltip',
      badge_content,
      'tooltip-text': tooltip_text,
    )
  end

  def badge_content
    render BadgeComponent.new(
      **tag_options,
      class: 'usa-tooltip',
    ).with_content(content)
  end
end
