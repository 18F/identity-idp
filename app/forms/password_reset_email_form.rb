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
    FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_writer :email

  def extra_analytics_attributes
    {
      user_id: user.uuid,
      role: user.role,
      confirmed: user.confirmed?,
    }
  end

  def user
    @_user ||= User.find_with_email(email) || NonexistentUser.new
  end
end
