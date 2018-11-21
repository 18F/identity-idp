class MarkUserAsMfaEnabled
  def initialize(user)
    @user = user
  end

  def call
    return if user.mfa_enabled?

    UpdateUser.new(user: user, attributes: { mfa_enabled: true }).call
  end

  private

  attr_reader :user
end
