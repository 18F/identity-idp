class UpdateUserEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_accessor :email
  attr_reader :user

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
      @user.update(params)
    else
      process_errors(params)
    end
  end

  def valid_form?
    valid? && !email_taken?
  end

  def mobile_changed?
    false
  end

  private

  def email_taken?
    @email_taken == true
  end

  def process_errors(params)
    return false unless email_taken? && valid?

    @user.skip_confirmation_notification!
    UserMailer.signup_with_your_email(email).deliver_later
    @user.update(params)
  end
end
