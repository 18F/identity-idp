class LoginButtonComponent < ButtonComponent
  attr_reader :action, :color, :logo_path, :tag_options

  def initialize(color: "primary", **tag_options)
    super(
      color: color,
      **tag_options
    )

    @color = color
  end

  def logo_path
    return "logo-white.svg" if color == "primary darker"
    "logo.svg"
  end

  def css_class
    classes = super || ['usa-button', *tag_options[:class]]
    classes << 'login-button login-button--primary' if color == "primary"
    classes << 'login-button login-button--primary-lighter' if color == "primary lighter"
    classes << 'login-button login-button--primary-darker' if color == "primary darker"
    classes
  end

end
