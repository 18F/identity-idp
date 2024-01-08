class LoginButtonComponentPreview < ButtonComponentPreview
  # @!group Preview
  def default
    render(LoginButtonComponent.new)
  end

  # @!endgroup

  # @param big toggle
  # @param color select [~,primary,primary-darker,primary-lighter]
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
