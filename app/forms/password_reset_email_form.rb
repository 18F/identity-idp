class PasswordResetEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :email

  def initialize(email)
    @email = email
  end

  def resend
    'true'
  end

  def submit
    @success = valid?

    result
  end

  private

  attr_reader :success

  def result
    {
      success: success,
      errors: errors.messages.values.flatten,
      user_id: user.uuid,
      role: user.role,
      confirmed: user.confirmed?
    }
  end

  def user
    @_user ||= User.find_with_email(email) || NonexistentUser.new
  end
end
