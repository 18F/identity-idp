# frozen_string_literal: true

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
      **initial_hidden_tag_options,
      'show-unsupported-passkey': show_unsupported_passkey?.presence,
    )
  end

  def initial_hidden_tag_options
    if platform? && passkey_supported_only?
      { hidden: true }
    else
      { class: 'js' }
    end
  end
end
