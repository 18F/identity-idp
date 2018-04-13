# rubocop:disable Rails/HasManyOrHasOneDependent
class User < ApplicationRecord
  include NonNullUuid

  after_validation :set_default_role, if: :new_record?

  devise(
    :confirmable,
    :database_authenticatable,
    :recoverable,
    :registerable,
    :timeoutable,
    :trackable,
    :two_factor_authenticatable,
    authentication_keys: [:email]
  )

  include EncryptableAttribute

  encrypted_attribute(name: :phone)
  encrypted_attribute(name: :otp_secret_key)
  encrypted_attribute_without_setter(name: :email)

  # IMPORTANT this comes *after* devise() call.
  include UserAccessKeyOverrides
  include UserEncryptedAttributeOverrides

  enum role: { user: 0, tech: 1, admin: 2 }
  enum otp_delivery_preference: { sms: 0, voice: 1 }

  has_one_time_password

  has_many :authorizations, dependent: :destroy
  has_many :identities # identities need to be orphaned to prevent UUID reuse
  has_many :agency_identities, dependent: :destroy
  has_many :profiles, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :x509_dn_uuid, uniqueness: true, allow_nil: true

  attr_accessor :asserted_attributes

  def personal_key
    recovery_code
  end

  def personal_key=(value)
    self.recovery_code = value
  end

  def set_default_role
    self.role ||= :user
  end

  def need_two_factor_authentication?(_request)
    two_factor_enabled?
  end

  def two_factor_enabled?
    phone.present? || totp_enabled?
  end

  def send_two_factor_authentication_code(_code)
    # The two_factor_authentication gem assumes that if a user needs to receive
    # a code, the code should be automatically sent right after Warden signs
    # the user in by calling this method. However, we don't want a code to be
    # automatically sent until the user has reached the TwoFactorAuthenticationController,
    # where we prompt them to select how they would like to receive the OTP code.
    #
    # Hence, we define this method as a no-op method, meaning it doesn't do anything.
    # See https://github.com/18F/identity-idp/pull/452 for more details.
  end

  def confirmation_period_expired?
    confirmation_sent_at.present? && confirmation_sent_at.utc <= self.class.confirm_within.ago
  end

  def first_identity
    active_identities[0]
  end

  def last_identity
    active_identities[-1] || NullIdentity.new
  end

  def active_identities
    identities.where(
      'session_uuid IS NOT ?',
      nil
    ).order(
      last_authenticated_at: :asc
    ) || []
  end

  def multiple_identities?
    active_identities.size > 1
  end

  def active_profile
    @_active_profile ||= profiles.verified.find(&:active?)
  end

  # To send emails asynchronously via ActiveJob.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def decorate
    UserDecorator.new(self)
  end

  # Devise automatically downcases and strips any attribute defined in
  # config.case_insensitive_keys and config.strip_whitespace_keys via
  # before_validation callbacks. Email is included by default, which means that
  # every time the User model is saved, even if the email wasn't updated, a DB
  # call will be made to downcase and strip the email.

  # To avoid these unnecessary DB calls, we've set case_insensitive_keys and
  # strip_whitespace_keys to empty arrays in config/initializers/devise.rb.
  # In addition, we've overridden the downcase_keys and strip_whitespace
  # methods below to do nothing.
  #
  # Note that we already downcase and strip emails, and only when necessary
  # (i.e. when the email attribute is being created or updated, and when a user
  # is entering an email address in a form). This is the proper way to handle
  # this formatting, as opposed to via a model callback that performs this
  # action regardless of whether or not it is needed. Search the codebase for
  # ".downcase.strip" for examples.
  def downcase_keys
    # no-op
  end

  def strip_whitespace
    # no-op
  end

  # In order to pass in the SP request_id to the confirmation instructions
  # email, we need to define `send_custom_confirmation_instructions` because
  # Devise's `send_confirmation_instructions` does not include arguments.
  # We also need to override the Devise method to do nothing because this method
  # is called automatically when a user is created due to a Devise callback.
  # If we didn't disable it, the user would receive two confirmation emails.
  def send_confirmation_instructions
    # no-op
  end

  def send_custom_confirmation_instructions(id = nil, instructions = nil)
    generate_confirmation_token! unless @raw_confirmation_token

    opts = pending_reconfirmation? ? { to: unconfirmed_email, request_id: id } : { request_id: id }
    opts[:first_sentence] = instructions if instructions
    send_devise_notification(:confirmation_instructions,
                             @raw_confirmation_token, opts)
  end
end
# rubocop:enable Rails/HasManyOrHasOneDependent
