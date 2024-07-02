# frozen_string_literal: true

class TooltipComponent < BaseComponent
  attr_reader :tooltip_text, :tag_options

  def initialize(tooltip_text:, **tag_options)
    @tooltip_text = tooltip_text
    @tag_options = tag_options
  end

  def call
    content_tag(:'lg-tooltip', content, **tag_options, 'tooltip-text': tooltip_text)
  end
end
