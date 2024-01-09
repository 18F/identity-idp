class LoginButtonComponent < ButtonComponent
  VALID_COLORS = ['primary', 'primary-darker', 'primary-lighter'].freeze

  attr_reader :color, :tag_options

  def initialize(color: 'primary', **tag_options)
    if !VALID_COLORS.include?(color)
      raise ArgumentError, "`color` #{color}} is invalid, expected one of #{VALID_COLORS}"
    end

    super(
      color: color,
      **tag_options
    )

    @color = color
  end

  def logo_class
    return 'login-button__logo login-button__logo-white' if color == 'primary-darker'
    'login-button__logo'
  end

  def css_class
    classes = super || ['usa-button', *tag_options[:class]]
    classes << "login-button login-button--#{color}"
    classes
  end
end
