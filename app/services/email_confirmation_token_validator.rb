class EmailConfirmationTokenValidator
  include ActiveModel::Model

  validate :token_not_expired

  def initialize(user)
    @user = user
  end

  def submit
    @success = valid? && user_valid?

    result
  end

  private

  attr_accessor :user
  attr_reader :success

  def result
    {
      success: success,
      error: [errors.full_messages, user.errors.full_messages].join,
      user_id: user.uuid,
      existing_user: user.confirmed?,
    }
  end

  def user_valid?
    user.errors.empty?
  end

  def token_not_expired
    errors.add(:confirmation_token, 'has expired') if user.confirmation_period_expired?
  end
end
