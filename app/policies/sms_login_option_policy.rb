class SmsLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    user.phone_configuration.present?
  end

  private

  attr_reader :user
end
