# frozen_string_literal: true

class AnimatedMediaComponent < BaseComponent
  attr_reader :image, :alt, :width, :height, :tag_options

  def initialize(image:, alt:, width: nil, height: nil, **tag_options)
    @image = image
    @alt = alt
    @width = width
    @height = height
    @tag_options = tag_options
  end

  def css_class
    ['ads-animated-media', *tag_options[:class]]
  end
end
