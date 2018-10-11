class UpdateUserEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :email, :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.email = @user.email_address.email
  end

  def submit(params)
    self.email = params[:email]

    if valid_form?
      @success = true
      update_user_email if email_changed?
    else
      @success = process_errors
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def valid_form?
    valid? && !email_taken?
  end

  def email_changed?
    valid? && email != @user.email_address.email
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

  def extra_analytics_attributes
    {
      email_already_exists: email_taken?,
      email_changed: email_changed?,
    }
  end

  def update_user_email
    UpdateUser.new(user: @user, attributes: { email: email }).call
    @user.send_custom_confirmation_instructions
  end
end
