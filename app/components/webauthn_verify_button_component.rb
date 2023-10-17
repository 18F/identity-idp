# frozen_string_literal: true

class WebauthnVerifyButtonComponent < BaseComponent
  attr_reader :credentials, :user_challenge, :button_options, :tag_options

  def initialize(user_challenge:, credentials: nil, button_options: nil, **tag_options)
    @credentials = credentials
    @user_challenge = user_challenge
    @tag_options = tag_options
    @button_options = button_options
  end
end
