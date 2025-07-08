# frozen_string_literal: true

class WebauthnInputComponent < BaseComponent
  attr_reader :platform, :passkey_supported_only, :tag_options

  alias_method :platform?, :platform
  alias_method :passkey_supported_only?, :passkey_supported_only

  def initialize(
    platform: false,
    passkey_supported_only: false,
    **tag_options
  )
    @platform = platform
    @passkey_supported_only = passkey_supported_only
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-webauthn-input',
      content,
      **tag_options,
      **initial_hidden_tag_options,
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
