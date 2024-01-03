class LoginButtonComponentPreview < ButtonComponentPreview
  # @!group Preview
  def default
    render(LoginButtonComponent.new.with_content('Sign in with'))
  end

  # @!endgroup

  # rubocop:disable Layout/LineLength
  # @param content text
  # @param big toggle
  # @param color select [~,primary,primary darker,primary lighter]
  def workbench(
    content: 'Sign in with',
    big: false,
    color: "primary"
  )
  
    render(
      LoginButtonComponent.new(
        big:,
        color:,
      ).with_content(content),
    )
  end
  # rubocop:enable Layout/LineLength
end
