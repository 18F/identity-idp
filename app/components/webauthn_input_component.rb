class WebauthnInputComponent < BaseComponent
  attr_reader :platform

  def initialize(platform: false)
    @platform = platform
  end

  def call
    content_tag(
      :'lg-webauthn-input',
      content,
      hidden: true,
      platform: platform.presence,
    )
  end
end
