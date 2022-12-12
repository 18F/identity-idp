class PasswordResetTokenValidator
  include ActiveModel::Model

  validates :user, presence: { message: 'invalid_token' }
  validate :valid_token, if: :user

  def initialize(user)
    @user = user
  end

  def submit
    FormResponse.new(success: valid?, errors: errors, extra: { user_id: user&.uuid })
  end

  private

  attr_accessor :user

  def valid_token
    return if user.reset_password_period_valid?
    errors.add(:user, 'token_expired', type: :token_expired)
  end
end
