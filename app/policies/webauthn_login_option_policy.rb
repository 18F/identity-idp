# The WebauthnLoginOptionPolicy class is responsible for handling the user policy of webauthn
class WebauthnLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    FeatureManagement.webauthn_enabled? && user.webauthn_configurations.any?
  end

  private

  attr_reader :user
end
