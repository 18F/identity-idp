class LoginButtonComponentPreview < BaseComponentPreview
  include ActionView::Context
  include ActionView::Helpers::TagHelper

  # @!group Preview
  def default
    render(LoginButtonComponent.new.with_content('Sign in with'))
  end

  def login_image_url
    asset_path('logo.svg')
  end

  def big
    render(LoginButtonComponent.new(big: true).with_content('Sign in with'))
  end

  def with_custom_action
    render(
      LoginButtonComponent.new(
        action: ->(**tag_options, &block) do
          content_tag(:'lg-custom-button', **tag_options, &block)
        end,
      ).with_content('Sign in with'),
    )
  end
  # @!endgroup

  # rubocop:disable Layout/LineLength
  # @param content text
  # @param big toggle
  # @param color select [~,light blue,dark blue,white]
  def workbench(
    content: 'Sign in with',
    big: false,
    outline: false,
    color: "light blue"
  )
    render(
      LoginButtonComponent.new(
        big:,
        outline:,
        color:,
      ).with_content(content),
    )
  end
  # rubocop:enable Layout/LineLength
end
