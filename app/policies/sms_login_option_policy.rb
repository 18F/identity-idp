class SmsLoginOptionPolicy
  def initialize(user)
    @user = user&.mfa
  end

  def configured?
    return false unless user
    user.phone_configurations.any?(&:mfa_enabled?)
  end

  private

  attr_reader :user
end
