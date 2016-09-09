class RegisterUserEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  delegate :email, to: :user

  def user
    @user ||= User.new
  end

  def submit(params)
    user.email = params[:email].downcase

    if valid_form?
      user.save!
    else
      process_errors
    end
  end

  def email_taken?
    @email_taken == true
  end

  private

  def valid_form?
    valid? && !email_taken?
  end

  def process_errors
    # To prevent discovery of existing emails, we check to see if the email is
    # already taken and if so, we act as if the user registration was successful.
    if email_taken?
      UserMailer.signup_with_your_email(email).deliver_later
      return true
    end

    false
  end
end
