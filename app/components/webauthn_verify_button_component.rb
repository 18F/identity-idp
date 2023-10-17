class WebauthnVerifyButtonComponent < BaseComponent
  attr_reader :credentials, :user_challenge, :tag_options

  def initialize(user_challenge:, credentials: nil, **tag_options)
    @credentials = credentials
    @user_challenge = user_challenge
    @tag_options = tag_options
  end
end
