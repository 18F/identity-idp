class UpdateUserEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_accessor :email

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.email = @user.email
  end

  def submit(params)
    set_attributes(params)

    if valid_form?
      @user.update(params)
    else
      process_errors(params)
    end
  end

  def valid_form?
    valid? && !email_taken?
  end

  private

  def set_attributes(params)
    self.email = params[:email]
  end

  def email_taken?
    @email_taken == true
  end

  def process_errors(params)
    # To prevent discovery of existing emails, we check
    # to see if the only errors are "already taken" errors, and if so, we
    # act as if the user update was successful.
    if email_taken? && valid?
      @user.skip_confirmation_notification! if email_taken?
      send_notifications
      @user.update(params)
      return true
    end

    false
  end

  def send_notifications
    UserMailer.signup_with_your_email(email).deliver_later if email_taken?
  end
end
