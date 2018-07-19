class AuthAppLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    !user.otp_secret_key.nil?
  end

  private

  attr_reader :user
end
