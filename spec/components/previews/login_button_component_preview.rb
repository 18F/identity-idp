class LoginButtonComponentPreview < ButtonComponentPreview
  # @!group Preview
  def default
    render(LoginButtonComponent.new(style: get_css))
  end
  # @!endgroup

  # @param big toggle "Change button size"
  # @param color select [primary,primary-darker,primary-lighter] "Select button color"
  def workbench(
    big: false,
    color: 'primary'
  )
    render(
      LoginButtonComponent.new(
        big:,
        color:,
      ),
    )
  end

  def css_file_path
    Rails.root.join(
      'app',
      'assets',
      'builds',
      'login_button_component.css',
    )
  end

  def get_css
    File.read(css_file_path)
  end

end
