class ResendEmailConfirmationForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :email

  def initialize(email = nil)
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
      confirmed: user.confirmed?
    }
  end

  def user
    @_user ||= (email.presence && User.find_with_email(email)) || NonexistentUser.new
  end
end
