class LoginButtonComponent < BaseComponent
  VALID_COLORS = ['primary', 'primary-darker', 'primary-lighter'].freeze

  attr_reader :color, :big, :tag_options

  def initialize(color: 'primary', big: false, **tag_options)
    if !VALID_COLORS.include?(color)
      raise ArgumentError, "`color` #{color}} is invalid, expected one of #{VALID_COLORS}"
    end

    @big = big
    @color = color
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << "login-button login-button--#{color}"
    classes
  end
end
