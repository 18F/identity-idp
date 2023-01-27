class RegisterUserEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include FormEmailValidator

  validate :validate_terms_accepted
  validates_inclusion_of :email_language, in: I18n.available_locales.map(&:to_s).append(nil)

  attr_reader :email_address, :terms_accepted
  attr_accessor :email_language
  attr_accessor :password_reset_requested

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(analytics:, attempts_tracker:, password_reset_requested: false)
    @throttled = false
    @password_reset_requested = password_reset_requested
    @analytics = analytics
    @attempts_tracker = attempts_tracker
  end

  def user
    @user ||= User.new
  end

  def email
    email_address&.email
  end

  def validate_terms_accepted
    return if @terms_accepted

    errors.add(:terms_accepted, t('errors.registration.terms'), type: :terms)
  end

  def submit(params, instructions = nil)
    @terms_accepted = params[:terms_accepted] == '1'
    build_user_and_email_address_with_email(
      email: params[:email],
      email_language: params[:email_language],
    )
    self.request_id = params[:request_id]
    if valid?
      process_successful_submission(request_id, instructions)
    else
      self.success = false
    end

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
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

    self.email_language = email_language
    user.email_language = email_language
  end

  def lookup_email_taken
    email_owner = email_address_record&.user
    return false if email_owner.blank?
    return email_address_record.confirmed? if email_owner.confirmed?
    true
  end

  def process_successful_submission(request_id, instructions)
    self.success = true
    if email_taken? && user_unconfirmed?
      send_sign_up_unconfirmed_email(request_id)
    elsif email_taken?
      send_sign_up_confirmed_email
    else
      user.accepted_terms_at = Time.zone.now
      user.save!
      SendSignUpEmailConfirmation.new(user).call(
        request_id: email_request_id(request_id),
        instructions: instructions,
        password_reset_requested: password_reset_requested?,
      )
    end
  end

  def extra_analytics_attributes
    {
      email_already_exists: email_taken?,
      user_id: user.uuid || existing_user.uuid,
      domain_name: email&.split('@')&.last,
      throttled: @throttled,
    }
  end

  def send_sign_up_unconfirmed_email(request_id)
    throttler = Throttle.new(user: existing_user, throttle_type: :reg_unconfirmed_email)
    @throttled = throttler.throttled_else_increment?

    if @throttled
      @analytics.throttler_rate_limit_triggered(
        throttle_type: :reg_unconfirmed_email,
      )
      @attempts_tracker.user_registration_email_submission_rate_limited(
        email: email, email_already_registered: false,
      )
    else
      SendSignUpEmailConfirmation.new(existing_user).call(request_id: request_id)
    end
  end

  def send_sign_up_confirmed_email
    throttler = Throttle.new(user: existing_user, throttle_type: :reg_confirmed_email)
    @throttled = throttler.throttled_else_increment?

    if @throttled
      @analytics.throttler_rate_limit_triggered(
        throttle_type: :reg_confirmed_email,
      )
      @attempts_tracker.user_registration_email_submission_rate_limited(
        email: email, email_already_registered: true,
      )
    else
      UserMailer.with(user: existing_user, email_address: email_address_record).
        signup_with_your_email.deliver_now_or_later
    end
  end

  def user_unconfirmed?
    existing_user.email_addresses.none?(&:confirmed?)
  end

  def email_address_record
    return @email_address_record if defined?(@email_address_record)
    @email_address_record = EmailAddress.find_with_email(email)
    @email_address_record
  end

  def existing_user
    @existing_user ||= email_address_record&.user || AnonymousUser.new
  end

  def email_request_id(request_id)
    request_id if request_id.present? && ServiceProviderRequestProxy.find_by(uuid: request_id)
  end
end
