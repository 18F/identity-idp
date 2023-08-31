class WebauthnInputComponent < BaseComponent
  attr_reader :platform, :tag_options

  alias_method :platform?, :platform

  def initialize(platform: false, **tag_options)
    @platform = platform
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-webauthn-input',
      content,
      **tag_options,
      hidden: true,
      platform: platform.presence,
    )
  end
end
