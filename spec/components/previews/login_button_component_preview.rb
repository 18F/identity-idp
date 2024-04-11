class LoginButtonComponentPreview < ButtonComponentPreview
  # @!group Preview
  # @after_render :inject_style
  def default
    render(LoginButtonComponent.new)
  end
  # @!endgroup

  # @after_render :inject_style
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

  private

  def css_file_path
    Rails.root.join(
      'app',
      'assets',
      'builds',
      'login_button_component.css',
    )
  end

  def inject_style(html)
    <<~HTML
      <style>
        #{css_file_path.read}
      </style>
      #{html}
    HTML
  end
end
