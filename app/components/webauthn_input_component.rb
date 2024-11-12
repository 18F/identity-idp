# frozen_string_literal: true

class WebauthnInputComponent < BaseComponent
  attr_reader :platform, :passkey_supported_only, :show_unsupported_passkey,
              :desktop_ft_unlock_option, :tag_options

  alias_method :platform?, :platform
  alias_method :passkey_supported_only?, :passkey_supported_only
  alias_method :show_unsupported_passkey?, :show_unsupported_passkey
  alias_method :desktop_ft_unlock_option?, :desktop_ft_unlock_option

  def initialize(
    platform: false,
    passkey_supported_only: false,
    show_unsupported_passkey: false,
    desktop_ft_unlock_option: false,
    **tag_options
  )
    @platform = platform
    @passkey_supported_only = passkey_supported_only
    @show_unsupported_passkey = show_unsupported_passkey
    @desktop_ft_unlock_option = desktop_ft_unlock_option
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-webauthn-input',
      content,
      **tag_options,
      **initial_hidden_tag_options,
      'show-unsupported-passkey': show_unsupported_passkey?.presence,
      'desktop-ft-unlock-option': show_desktop_ft_unlock_option?.presence,
    )
  end

  def initial_hidden_tag_options
    if platform? && passkey_supported_only?
      { hidden: true }
    else
      { class: 'js' }
    end
  end

  def show_desktop_ft_unlock_option?
    if desktop_ft_unlock_option? && I18n.locale == :en
      true
    else
      false
    end
  end
end
