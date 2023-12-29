class LoginButtonComponentPreview < BaseComponentPreview
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  # @!group Preview
  def default
    render(LoginButtonComponent.new.with_content('Sign in with'))
  end

  def big
    render(LoginButtonComponent.new(big: true).with_content('Sign in with'))
  end

  # @!endgroup

  # rubocop:disable Layout/LineLength
  # @param content text
  # @param big toggle
  # @param color select [~,light blue,dark blue,white]
  def workbench(
    content: 'Sign in with',
    big: false,
    color: "light blue"
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
