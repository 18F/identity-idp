class SmsLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    user.phone.present?
  end

  private

  attr_reader :user
end
