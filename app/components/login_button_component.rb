class LoginButtonComponent < ButtonComponent
  attr_reader :action, :color, :logo_path, :tag_options

  def initialize(color: "light blue", **tag_options)
    super(
      color: color,
      **tag_options
    )

    @color = color
  end

  def logo_path
    return "logo-white.svg" if color == "dark blue"
    "logo.svg"
  end

  #   <%= image_tag(asset_url(logo_path), alt: t('components.login_button.image_alt'), class: 'display-inline text-middle margin-left-1 margin-top-neg-05') %>

  def css_class
    classes = super || ['usa-button', *tag_options[:class]]
    classes << 'bg-white text-primary-darker border border-base hover:border hover:bg-white hover:text-primary-darker hover:border-base' if color == "white"
    classes << 'bg-primary-lighter text-primary-darker hover:bg-primary-lighter hover:text-primary-darker' if color == "light blue"
    classes << 'bg-primary-darker text-white hover:bg-primary-darker hover:text-white' if color == "dark blue"
    classes
  end

  # def content
  #   super || image_tag(asset_url(logo_path), alt: t('components.login_button.image_alt'), class: 'display-inline text-middle margin-left-1 margin-top-neg-05')
  # end

end
