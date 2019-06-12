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

  def submit(user, params)
    @user = user
    @email_address = new_email_address(params)
    @email = params[:email]

    if valid_form?
      process_successful_submission
    else
      @success = false
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
    @allow && valid?
  end

  def process_successful_submission
    @success = true
    email_address.save!
    SendAddEmailConfirmation.new(user).call(email_address)
  end

  def extra_analytics_attributes
    {
      user_id: existing_user.uuid,
      domain_name: email&.split('@')&.last,
    }.merge(@recaptcha_h)
  end

  def existing_user
    @_user ||= User.find_with_email(email) || AnonymousUser.new
  end
end
