class RegisterUserEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include FormEmailValidator

  validate :service_provider_request_exists

  attr_reader :email_address
  attr_accessor :email_language
  attr_accessor :password_reset_requested

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(recaptcha_results: [true, {}], password_reset_requested: false)
    @allow, @recaptcha_h = recaptcha_results
    @throttled = false
    @password_reset_requested = password_reset_requested
  end

  def user
    @user ||= User.new
  end

  def email
    email_address&.email
  end

  def resend
    'true'
  end

  def submit(params, instructions = nil)
    build_user_and_email_address_with_email(
      email: params[:email],
      email_language: params[:email_language],
    )
    self.request_id = params[:request_id]
    if valid_form?
      process_successful_submission(request_id, instructions)
    else
      self.success = @allow && process_errors(request_id)
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def email_taken?
    return @email_taken unless @email_taken.nil?
    @email_taken = lookup_email_taken
  end

  def password_reset_requested?
    @password_reset_requested
  end

  private

  attr_writer :email, :email_address
  attr_accessor :success, :request_id

  def build_user_and_email_address_with_email(email:, email_language:)
    self.email_address = user.email_addresses.build(
      user: user,
      email: email,
    )
    user.email = email # Delete this when email address is retired

    self.email_language = email_language
    user.email_language = email_language
  end

  def valid_form?
    @allow && valid? && !email_taken?
  end

  def lookup_email_taken
    email_address = EmailAddress.find_with_email(email)
    email_owner = email_address&.user
    return false if email_owner.blank?
    return email_address.confirmed? if email_owner.confirmed?
    true
  end

  def service_provider_request_exists
    return if request_id.blank?
    return if ServiceProviderRequestProxy.find_by(uuid: request_id)
    errors.add(:email, t('sign_up.email.invalid_request'))
  end

  def process_successful_submission(request_id, instructions)
    self.success = true
    user.save!
    Funnel::Registration::Create.call(user.id)
    SendSignUpEmailConfirmation.new(user).call(request_id: request_id,
                                               instructions: instructions,
                                               password_reset_requested: password_reset_requested?)
  end

  def extra_analytics_attributes
    {
      email_already_exists: email_taken?,
      user_id: user.uuid || existing_user.uuid,
      domain_name: email&.split('@')&.last,
      throttled: @throttled,
    }.merge(@recaptcha_h)
  end

  def process_errors(request_id)
    # To prevent discovery of existing emails, we check to see if the email is
    # already taken and if so, we act as if the user registration was successful.
    if email_taken? && user_unconfirmed?
      send_sign_up_unconfirmed_email(request_id)
      true
    elsif email_taken?
      send_sign_up_confirmed_email
      true
    else
      false
    end
  end

  def send_sign_up_unconfirmed_email(request_id)
    @throttled = Throttler::IsThrottledElseIncrement.call(existing_user.id, :reg_unconfirmed_email)
    SendSignUpEmailConfirmation.new(existing_user).call(request_id: request_id) unless @throttled
  end

  def send_sign_up_confirmed_email
    @throttled = Throttler::IsThrottledElseIncrement.call(existing_user.id, :reg_confirmed_email)
    UserMailer.signup_with_your_email(existing_user, email).deliver_later unless @throttled
  end

  def user_unconfirmed?
    existing_user.email_addresses.none?(&:confirmed?)
  end

  def existing_user
    @_user ||= User.find_with_email(email) || AnonymousUser.new
  end
end
