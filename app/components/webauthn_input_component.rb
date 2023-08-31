class WebauthnInputComponent < BaseComponent
  attr_reader :platform, :passkey_supported_only, :tag_options

  alias_method :platform?, :platform
  alias_method :passkey_supported_only?, :passkey_supported_only

  def initialize(platform: false, passkey_supported_only: false, **tag_options)
    @platform = platform
    @passkey_supported_only = passkey_supported_only
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-webauthn-input',
      content,
      **tag_options,
      hidden: true,
      platform: platform.presence,
      'passkey-supported-only': passkey_supported_only.presence,
    )
  end
end
