class UpdateUserEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :email, :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.email = @user.email
  end

  def submit(params)
    self.email = params[:email]

    if valid_form?
      @success = true
      UpdateUser.new(user: @user, attributes: { email: email }).call
    else
      @success = process_errors
    end

    result
  end

  def valid_form?
    valid? && !email_taken?
  end

  def email_changed?
    valid? && email != @user.email
  end

  private

  attr_writer :email
  attr_reader :email_changed, :success

  def process_errors
    return false unless email_taken? && valid?

    @user.skip_confirmation_notification!
    UserMailer.signup_with_your_email(email).deliver_later
    true
  end

  def result
    {
      success: success,
      errors: errors.messages.values.flatten,
      email_already_exists: email_taken?,
      email_changed: email_changed?,
    }
  end
end
