# frozen_string_literal: true

class LoginButtonComponent < BaseComponent
  VALID_COLORS = ['primary', 'primary-darker', 'primary-lighter'].freeze

  attr_reader :color, :big, :width, :height, :tag_options

  def initialize(color: 'primary', big: false, **tag_options)
    if !VALID_COLORS.include?(color)
      raise ArgumentError, "`color` #{color}} is invalid, expected one of #{VALID_COLORS}"
    end

    @big = big
    @width = big ? '10rem' : '7rem'
    @height = big ? '2rem' : '1.25rem'
    @color = color
    @tag_options = tag_options
  end

  def svg
    Rails.root.join(
      'app', 'assets', 'images',
      (color == "primary-darker" ? 'logo-white.svg' : 'logo.svg')
    ).read
  end

  def inject_svg
    # rubocop:disable Rails/OutputSafety
    Nokogiri::HTML5.fragment(svg).tap do |doc|
      doc.at_css('svg').tap do |svg|
        svg[:role] = 'img'
        svg[:width] = width
        svg[:height] = height
        svg << "<title>#{APP_NAME}</title>"
      end
    end.to_s.html_safe
    # rubocop:enable Rails/OutputSafety
  end


  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << "login-button login-button--#{color}"
    classes
  end
end
