class PasswordResetTokenValidator
  include ActiveModel::Model

  validates :user, presence: { message: 'invalid_token' }
  validate :valid_token, if: :user

  def initialize(user)
    @user = user
  end

  def submit
    FormResponse.new(success: valid?, errors: errors.messages, extra: { user_id: user&.uuid })
  end

  private

  attr_accessor :user

  def valid_token
    errors.add(:user, 'token_expired') unless user.reset_password_period_valid?
  end
end
