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
    @rate_limited = false
    @password_reset_requested = password_reset_requested
    @analytics = analytics
    @attempts_tracker = attempts_tracker
  end

  def user
    @user ||= User.new
  end

  def rate_limited?
    @rate_limited
  end

  def email
    email_address&.email
  end

  def email_fingerprint
    email_address&.email_fingerprint
  end

  def normalized_email
    @normalized_email ||= EmailNormalizer.new(email).normalized_email
  end

  def digested_base_email
    @digested_base_email ||= OpenSSL::Digest::SHA256.hexdigest(normalized_email)
  end

  def validate_terms_accepted
    return if @terms_accepted || email_address_record&.user&.accepted_terms_at.present?

    errors.add(:terms_accepted, t('errors.registration.terms'), type: :terms)
  end

  def submit(params, instructions = nil)
    @terms_accepted = params[:terms_accepted] == '1'
    build_user_and_email_address_with_email(
      email: params[:email],
      email_language: params[:email_language],
    )
    self.request_id = params[:request_id]

    self.success = valid?
    process_successful_submission(request_id, instructions) if success

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
    # To prevent discovery of existing emails, we check to see if the email is
    # already taken and if so, we act as if the user registration was successful.
    if email_address_record&.user&.suspended?
      send_suspended_user_email(email_address_record)
    elsif blocked_email_address
      send_suspended_user_email(blocked_email_address)
    elsif email_taken? && user_unconfirmed?
      update_user_language_preference
      send_sign_up_unconfirmed_email(request_id)
    elsif email_taken?
      send_sign_up_confirmed_email
    else
      send_sign_up_email(request_id, instructions)
    end
  end

  def update_user_language_preference
    if existing_user.email_language != email_language
      existing_user.update(email_language: email_language)
    end
  end

  def extra_analytics_attributes
    {
      email_already_exists: email_taken?,
      user_id: user.uuid || existing_user.uuid,
      domain_name: email&.split('@')&.last,
      rate_limited: rate_limited?,
    }
  end

  def rate_limit!(rate_limit_type)
    rate_limiter = RateLimiter.new(
      target: digested_base_email,
      rate_limit_type: rate_limit_type,
    )

    rate_limiter.increment!
    @rate_limited = rate_limiter.limited?
  end

  def send_sign_up_email(request_id, instructions)
    rate_limit!(:reg_unconfirmed_email)

    if rate_limited?
      @analytics.rate_limit_reached(
        limiter_type: :reg_unconfirmed_email,
      )
      @attempts_tracker.user_registration_email_submission_rate_limited(
        email: email, email_already_registered: false,
      )
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

  def send_sign_up_unconfirmed_email(request_id)
    rate_limit!(:reg_unconfirmed_email)

    if rate_limited?
      @analytics.rate_limit_reached(
        limiter_type: :reg_unconfirmed_email,
      )
      @attempts_tracker.user_registration_email_submission_rate_limited(
        email: email, email_already_registered: false,
      )
    else
      SendSignUpEmailConfirmation.new(existing_user).call(request_id: request_id)
    end
  end

  def send_sign_up_confirmed_email
    rate_limit!(:reg_confirmed_email)

    if rate_limited?
      @analytics.rate_limit_reached(
        limiter_type: :reg_confirmed_email,
      )
      @attempts_tracker.user_registration_email_submission_rate_limited(
        email: email, email_already_registered: true,
      )
    else
      UserMailer.with(user: existing_user, email_address: email_address_record).
        signup_with_your_email.deliver_now_or_later
    end
  end

  def send_suspended_user_email(suspended_email_record)
    UserMailer.with(
      user: suspended_email_record.user,
      email_address: suspended_email_record,
    ).suspended_create_account.deliver_now_or_later
  end

  def user_unconfirmed?
    existing_user.email_addresses.none?(&:confirmed?)
  end

  def email_address_record
    return @email_address_record if defined?(@email_address_record)

    @email_address_record = EmailAddress.find_with_email(email)
  end

  def existing_user
    @existing_user ||= email_address_record&.user || AnonymousUser.new
  end

  def email_request_id(request_id)
    request_id if request_id.present? && ServiceProviderRequestProxy.find_by(uuid: request_id)
  end

  def blocked_email_address
    return @blocked_email_address if defined?(@blocked_email_address)

    @blocked_email_address = SuspendedEmail.find_with_email_digest(digested_base_email)
  end
end
