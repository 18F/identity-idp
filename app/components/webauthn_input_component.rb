class WebauthnInputComponent < BaseComponent
  attr_reader :platform, :passkey_supported_only, :show_unsupported_passkey, :tag_options

  alias_method :platform?, :platform
  alias_method :passkey_supported_only?, :passkey_supported_only
  alias_method :show_unsupported_passkey?, :show_unsupported_passkey

  def initialize(
    platform: false,
    passkey_supported_only: false,
    show_unsupported_passkey: false,
    **tag_options
  )
    @platform = platform
    @passkey_supported_only = passkey_supported_only
    @show_unsupported_passkey = show_unsupported_passkey
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-webauthn-input',
      content,
      **tag_options,
      hidden: true,
      platform: platform?.presence,
      'passkey-supported-only': passkey_supported_only?.presence,
      'show-unsupported-passkey': show_unsupported_passkey?.presence,
    )
  end
end
