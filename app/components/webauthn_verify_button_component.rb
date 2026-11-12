# frozen_string_literal: true

class WebauthnVerifyButtonComponent < BaseComponent
  DEFAULT_BUTTON_CLASS = 'display-block margin-y-3'

  attr_reader :credentials, :user_challenge, :button_class, :tag_options

  # button_class: utility classes added to the submit button after its JS hook
  # class. Defaults to the legacy spacing; the NDS view passes nil so the NDS
  # actions stack controls spacing.
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
