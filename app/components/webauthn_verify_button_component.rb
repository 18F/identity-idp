# frozen_string_literal: true

class WebauthnVerifyButtonComponent < BaseComponent
  DEFAULT_BUTTON_CLASS = 'display-block margin-y-3'

  attr_reader :credentials, :user_challenge, :button_class, :tag_options

  def initialize(credentials:, user_challenge:, button_class: DEFAULT_BUTTON_CLASS, **tag_options)
    @credentials = credentials
    @user_challenge = user_challenge
    @button_class = button_class
    @tag_options = tag_options
  end

  def submit_button_class
    ['webauthn-verify-button__button', button_class.presence].compact.join(' ')
  end
end
