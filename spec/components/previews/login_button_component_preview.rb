class LoginButtonComponentPreview < ButtonComponentPreview
  # @!group Preview
  def default
    render(LoginButtonComponent.new)
  end

  # @!endgroup
  # @param big toggle "Change the size of the button"
  # @param color select [~,primary,primary-darker,primary-lighter] "Select your preferred button color"
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
end
