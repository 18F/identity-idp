class User < ApplicationRecord
  self.ignored_columns = %w[x509_dn_uuid otp_secret_key totp_timestamp]
  include NonNullUuid

  devise(
    :database_authenticatable,
    :recoverable,
    :registerable,
    :timeoutable,
    :trackable,
    authentication_keys: [:email],
  )

  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :email)

  # IMPORTANT this comes *after* devise() call.
  include UserAccessKeyOverrides
  include UserEncryptedAttributeOverrides
  include EmailAddressCallback
  include DeprecatedUserAttributes

  enum otp_delivery_preference: { sms: 0, voice: 1 }

  has_many :authorizations, dependent: :destroy
  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :identities # identities need to be orphaned to prevent UUID reuse
  has_many :events # we are retaining events after delete
  has_many :devices # we are retaining devices after delete
  # rubocop:enable Rails/HasManyOrHasOneDependent
  has_many :agency_identities, dependent: :destroy
  has_many :profiles, dependent: :destroy
  has_one :account_reset_request, dependent: :destroy
  has_many :phone_configurations, dependent: :destroy, inverse_of: :user
  has_many :email_addresses, dependent: :destroy, inverse_of: :user
  has_many :webauthn_configurations, dependent: :destroy, inverse_of: :user
  has_many :piv_cac_configurations, dependent: :destroy, inverse_of: :user
  has_many :auth_app_configurations, dependent: :destroy, inverse_of: :user
  has_one :doc_auth, dependent: :destroy, inverse_of: :user, class_name: 'DocAuthRecord'
  has_many :backup_code_configurations, dependent: :destroy
  has_one :doc_capture, dependent: :destroy
  has_many :document_capture_sessions, dependent: :destroy
  has_one :account_recovery_request, dependent: :destroy
  has_many :throttles, dependent: :destroy
  has_one :registration_log, dependent: :destroy
  has_one :proofing_component, dependent: :destroy
  has_many :service_providers,
           through: :identities,
           source: :service_provider_record

  attr_accessor :asserted_attributes

  def confirmed_email_addresses
    email_addresses.where.not(confirmed_at: nil)
  end

  def need_two_factor_authentication?(_request)
    MfaPolicy.new(self).two_factor_enabled?
  end

  def confirmed?
    email_addresses.where.not(confirmed_at: nil).any?
  end

  def set_reset_password_token
    super
  end

  def last_identity
    identities.where.not(session_uuid: nil).order(last_authenticated_at: :desc).take ||
      NullIdentity.new
  end

  def active_identities
    identities.where('session_uuid IS NOT ?', nil).order(last_authenticated_at: :asc) || []
  end

  def active_profile
    @_active_profile ||= profiles.verified.find(&:active?)
  end

  def default_phone_configuration
    phone_configurations.order('made_default_at DESC NULLS LAST, created_at').first
  end

  # To send emails asynchronously via ActiveJob.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def decorate
    UserDecorator.new(self)
  end

  def max_login_attempts?
    second_factor_attempts_count.to_i >= max_login_attempts
  end

  def max_login_attempts
    3
  end

  def create_direct_otp
    update(
      direct_otp: random_base10(TwoFactorAuthenticatable.direct_otp_length),
      direct_otp_sent_at: Time.zone.now,
    )
  end

  def generate_totp_secret
    ROTP::Base32.random_base32
  end

  def authenticate_direct_otp(code)
    return false if direct_otp.nil? || direct_otp != code || direct_otp_expired?
    clear_direct_otp
    true
  end

  def clear_direct_otp
    update(direct_otp: nil, direct_otp_sent_at: nil)
  end

  def direct_otp_expired?
    Time.zone.now > direct_otp_sent_at + TwoFactorAuthenticatable.direct_otp_valid_for_seconds
  end

  def random_base10(digits)
    SecureRandom.random_number(10**digits).to_s.rjust(digits, '0')
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
end
