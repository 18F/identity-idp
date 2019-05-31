class AddUserEmailForm
  include ActiveModel::Model
  include FormAddEmailValidator

  attr_reader :email

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(recaptcha_results = [true, {}])
    @allow, @recaptcha_h = recaptcha_results
  end

  def user
    @user ||= User.new
  end

  def resend
    'true'
  end

  def submit(user, params)
    @user = user
    @email_address = new_email_address(params)
    @email = params[:email]

    if valid_form?
      process_successful_submission
    else
      @success = @allow && process_errors
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def new_email_address(params)
    EmailAddress.new(user_id: user.id,
                     email: params[:email],
                     confirmation_token: SecureRandom.uuid,
                     confirmation_sent_at: Time.zone.now)
  end

  private

  attr_writer :email
  attr_reader :success, :email_address

  def valid_form?
    @allow && valid? && !email_taken?
  end

  def process_successful_submission
    @success = true
    email_address.save!
    SendAddEmailConfirmation.new(user).call
  end

  def extra_analytics_attributes
    {
      email_already_exists: email_taken?,
      user_id: existing_user.uuid,
      domain_name: email&.split('@')&.last,
    }.merge(@recaptcha_h)
  end

  def process_errors
    # To prevent discovery of existing emails, we check to see if the email is
    # already taken and if so, we act as if the add email was successful.
    if email_taken? && user_unconfirmed?
      SendAddEmailConfirmation.new(existing_user).call
      true
    elsif email_taken?
      UserMailer.signup_with_your_email(email).deliver_later
      true
    else
      false
    end
  end

  def user_unconfirmed?
    existing_user.email_addresses.none?(&:confirmed?)
  end

  def existing_user
    @_user ||= User.find_with_email(email) || AnonymousUser.new
  end
end
