class PasswordResetTokenValidator
  include ActiveModel::Model

  validates :user, presence: { message: 'invalid_token' }
  validate :valid_token, if: :user

  def initialize(user)
    @user = user
  end

  def submit
    @success = valid?

    result
  end

  private

  attr_accessor :user
  attr_reader :success

  def result
    {
      success: success,
      error: errors.messages.values.flatten.first,
      user_id: user&.uuid
    }
  end

  def valid_token
    errors.add(:user, 'token_expired') unless user.reset_password_period_valid?
  end
end
