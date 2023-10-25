# frozen_string_literal: true

class WebauthnVerifyButtonComponent < BaseComponent
  attr_reader :credentials, :user_challenge, :tag_options

  def initialize(credentials:, user_challenge:, **tag_options)
    @credentials = credentials
    @user_challenge = user_challenge
    @tag_options = tag_options
  end
end
