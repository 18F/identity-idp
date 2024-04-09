class LoginButtonComponentPreview < ButtonComponentPreview
  include ActiveModel::Conversion
  # @after_render :inject_style

  # @!group Preview
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

  def css
    File.read(css_file_path)
  end

  def inject_style(html)
    <<~HTML
      <style>
        #{css}
      </style>
      #{html}
    HTML
  end
end
