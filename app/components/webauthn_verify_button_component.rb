class WebauthnVerifyButtonComponent < BaseComponent
  attr_reader :credentials, :user_challenge, :mediation, :tag_options

  def initialize(user_challenge:, mediation: nil, credentials: nil, **tag_options)
    @credentials = credentials
    @user_challenge = user_challenge
    @tag_options = tag_options
    @mediation = mediation
  end
end
