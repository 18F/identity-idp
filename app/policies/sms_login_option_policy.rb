class SmsLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    return false unless user
    user.phone_configuration.present?
  end

  private

  attr_reader :user
end
