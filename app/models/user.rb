class User < ApplicationRecord
  self.ignored_columns = %w[totp_timestamp]
  include NonNullUuid

  include ::NewRelic::Agent::MethodTracer

  devise(
    :database_authenticatable,
    :recoverable,
    :registerable,
    :timeoutable,
    authentication_keys: [:email],
  )

  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :email)

  # IMPORTANT this comes *after* devise() call.
  include UserAccessKeyOverrides
  include UserEncryptedAttributeOverrides
  include EmailAddressCallback
  include DeprecatedUserAttributes
  include UserOtpMethods

  enum otp_delivery_preference: { sms: 0, voice: 1 }

  # rubocop:disable Rails/HasManyOrHasOneDependent
  # identities need to be orphaned to prevent UUID reuse
  has_many :identities, class_name: 'ServiceProviderIdentity'
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
  has_many :document_capture_sessions, dependent: :destroy
  has_many :throttles, dependent: :destroy
  has_one :registration_log, dependent: :destroy
  has_one :proofing_component, dependent: :destroy
  has_many :service_providers,
           through: :identities,
           source: :service_provider_record
  has_many :sign_in_restrictions, dependent: :destroy

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

  def accepted_rules_of_use_still_valid?
    if self.accepted_terms_at.present?
      self.accepted_terms_at > IdentityConfig.store.rules_of_use_updated_at &&
        self.accepted_terms_at > IdentityConfig.store.rules_of_use_horizon_years.years.ago
    end
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
    @active_profile ||= profiles.verified.find(&:active?)
  end

  def pending_profile?
    pending_profile.present?
  end

  def pending_profile
    profiles.verification_pending.order(created_at: :desc).first
  end

  def default_phone_configuration
    phone_configurations.order('made_default_at DESC NULLS LAST, created_at').first
  end

  def broken_personal_key?
    window_start = IdentityConfig.store.broken_personal_key_window_start
    window_finish = IdentityConfig.store.broken_personal_key_window_finish
    last_personal_key_at = self.encrypted_recovery_code_digest_generated_at

    (!last_personal_key_at || last_personal_key_at < window_finish) &&
      active_profile.present? &&
      (window_start..window_finish).cover?(active_profile.verified_at)
  end

  # To send emails asynchronously via ActiveJob.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_now_or_later
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

  add_method_tracer :send_devise_notification, "Custom/#{name}/send_devise_notification"
end
