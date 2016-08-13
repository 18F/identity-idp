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
    email = params[:email]
    if email != @user.email
      @email_changed = true
      self.email = email
    end

    if valid_form?
      @user.update(params)
    else
      process_errors(params)
    end
  end

  def valid_form?
    valid? && !email_taken?
  end

  def email_changed?
    @email_changed == true
  end

  def email_taken?
    @email_taken == true
  end

  private

  def process_errors(params)
    return false unless email_taken? && valid?

    @user.skip_confirmation_notification!
    UserMailer.signup_with_your_email(email).deliver_later
    @user.update(params)
  end
end
