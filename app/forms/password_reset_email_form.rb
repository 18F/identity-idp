class PasswordResetEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :email

  def initialize(email, recaptcha_results = [true, {}])
    @email = email
    @allow, @recaptcha_h = recaptcha_results
  end

  def resend
    'true'
  end

  def submit
    FormResponse.new(success: @allow && valid?, errors: errors.messages,
                     extra: extra_analytics_attributes)
  end

  private

  attr_writer :email

  def extra_analytics_attributes
    {
      user_id: user.uuid,
      role: user.role,
      confirmed: user.confirmed?,
    }.merge(@recaptcha_h)
  end

  def user
    @_user ||= User.find_with_email(email) || NonexistentUser.new
  end
end
