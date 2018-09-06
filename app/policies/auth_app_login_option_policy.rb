class AuthAppLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    user.otp_secret_key.present?
  end

  private

  attr_reader :user
end
