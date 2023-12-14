class User < ApplicationRecord
  include NonNullUuid

  include ::NewRelic::Agent::MethodTracer
  include ActionView::Helpers::DateHelper

  devise(
    :database_authenticatable,
    :recoverable,
    :registerable,
    :timeoutable,
    authentication_keys: [:email],
  )

  include EncryptableAttribute

  # IMPORTANT this comes *after* devise() call.
  include UserAccessKeyOverrides
  include UserEncryptedAttributeOverrides
  include DeprecatedUserAttributes
  include UserOtpMethods

  MAX_RECENT_EVENTS = 5
  MAX_RECENT_DEVICES = 5

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
  has_many :backup_code_configurations, dependent: :destroy
  has_many :document_capture_sessions, dependent: :destroy
  has_one :registration_log, dependent: :destroy
  has_one :proofing_component, dependent: :destroy
  has_many :service_providers,
           through: :identities,
           source: :service_provider_record
  has_many :sign_in_restrictions, dependent: :destroy
  has_many :in_person_enrollments, dependent: :destroy
  has_many :fraud_review_requests, dependent: :destroy

  has_one :pending_in_person_enrollment,
          -> { where(status: :pending).order(created_at: :desc) },
          class_name: 'InPersonEnrollment', foreign_key: :user_id, inverse_of: :user,
          dependent: :destroy

  has_one :establishing_in_person_enrollment,
          -> { where(status: :establishing).order(created_at: :desc) },
          class_name: 'InPersonEnrollment', foreign_key: :user_id, inverse_of: :user,
          dependent: :destroy

  attr_accessor :asserted_attributes, :email

  def confirmed_email_addresses
    email_addresses.where.not(confirmed_at: nil).order('last_sign_in_at DESC NULLS LAST')
  end

  def fully_registered?
    !!registration_log&.registered_at
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
    return @active_profile if defined?(@active_profile) &&
                              (@active_profile.nil? || @active_profile.active)

    @active_profile = profiles.verified.find(&:active?)
  end

  def pending_profile?
    pending_profile.present?
  end

  def gpo_verification_pending_profile?
    gpo_verification_pending_profile.present?
  end

  def suspended?
    suspended_at.to_s > reinstated_at.to_s
  end

  def reinstated?
    reinstated_at.to_s > suspended_at.to_s
  end

  def suspend!
    if suspended?
      analytics.user_suspended(success: false, error_message: :user_already_suspended)
      raise 'user_already_suspended'
    end
    OutOfBandSessionAccessor.new(unique_session_id).destroy if unique_session_id
    update!(suspended_at: Time.zone.now, unique_session_id: nil)
    analytics.user_suspended(success: true)

    event = PushNotification::AccountDisabledEvent.new(user: self)
    PushNotification::HttpPush.deliver(event)

    email_addresses.map do |email_address|
      SuspendedEmail.create_from_email_address!(email_address)
    end
  end

  def reinstate!
    if !suspended?
      analytics.user_reinstated(success: false, error_message: :user_is_not_suspended)
      raise 'user_is_not_suspended'
    end
    update!(reinstated_at: Time.zone.now)
    analytics.user_reinstated(success: true)

    event = PushNotification::AccountEnabledEvent.new(user: self)
    PushNotification::HttpPush.deliver(event)

    email_addresses.map do |email_address|
      SuspendedEmail.find_with_email(email_address.email)&.destroy
    end
    send_email_to_all_addresses(:account_reinstated)
  end

  def pending_profile
    return @pending_profile if defined?(@pending_profile) && !@pending_profile&.active

    @pending_profile = begin
      pending = profiles.in_person_verification_pending.or(
        profiles.gpo_verification_pending,
      ).or(
        profiles.fraud_review_pending,
      ).or(
        profiles.fraud_rejection,
      ).order(created_at: :desc).first

      if pending.blank?
        nil
      elsif pending.password_reset? || pending.encryption_error? || pending.verification_cancelled?
        # Profiles that are cancelled for reasons that do not require further verification steps
        # are not pending profiles
        nil
      elsif active_profile.present? && active_profile.activated_at > pending.created_at
        # If there is an active profile that is older than this pending profile that means the user
        # has proofed since this profile was created. That profile takes precedence and there is no
        # pending profile
        nil
      else
        pending
      end
    end
  end

  def gpo_verification_pending_profile
    pending_profile if pending_profile&.gpo_verification_pending?
  end

  def fraud_review_pending?
    fraud_review_pending_profile.present?
  end

  def fraud_rejection?
    fraud_rejection_profile.present?
  end

  def fraud_review_pending_profile
    pending_profile if pending_profile&.fraud_review_pending?
  end

  def fraud_rejection_profile
    pending_profile if pending_profile&.fraud_rejection?
  end

  def in_person_pending_profile?
    in_person_pending_profile.present?
  end

  def in_person_pending_profile
    pending_profile if pending_profile&.in_person_verification_pending?
  end

  def has_in_person_enrollment?
    pending_in_person_enrollment.present? || establishing_in_person_enrollment.present?
  end

  # Trust `pending_profile` rather than enrollment associations
  def has_establishing_in_person_enrollment_safe?
    !!pending_profile&.in_person_enrollment&.establishing?
  end

  def personal_key_generated_at
    encrypted_recovery_code_digest_generated_at ||
      active_profile&.verified_at ||
      profiles.verified.order(activated_at: :desc).first&.verified_at
  end

  def default_phone_configuration
    phone_configurations.order('made_default_at DESC NULLS LAST, created_at').first
  end

  ##
  # @param [String] issuer
  # @return [Boolean] Whether the user should receive a survey for completing in-person proofing
  def should_receive_in_person_completion_survey?(issuer)
    Idv::InPersonConfig.enabled_for_issuer?(issuer) &&
      in_person_enrollments.
        where(issuer: issuer, status: :passed).order(created_at: :desc).
        pick(:follow_up_survey_sent) == false
  end

  ##
  # Record that the in-person proofing survey was sent
  # @param [String] issuer
  def mark_in_person_completion_survey_sent(issuer)
    enrollment_id, follow_up_survey_sent = in_person_enrollments.
      where(issuer: issuer, status: :passed).
      order(created_at: :desc).
      pick(:id, :follow_up_survey_sent)

    if follow_up_survey_sent == false
      # Enrollment record is present and survey was not previously sent
      InPersonEnrollment.update(enrollment_id, follow_up_survey_sent: true)
    end
    nil
  end

  def increment_second_factor_attempts_count!
    User.transaction do
      sql = <<~SQL
        UPDATE users
        SET
          second_factor_attempts_count = COALESCE(second_factor_attempts_count, 0) + 1,
          updated_at = NOW(),
          second_factor_locked_at = CASE
            WHEN COALESCE(second_factor_attempts_count, 0) + 1 >= ?
            THEN NOW()
            ELSE NULL
            END
        WHERE id = ?
        RETURNING second_factor_attempts_count, second_factor_locked_at;
      SQL
      query = User.sanitize_sql_array(
        [sql,
         IdentityConfig.store.login_otp_confirmation_max_attempts, self.id],
      )
      result = User.connection.execute(query).first
      self.second_factor_attempts_count = result.fetch('second_factor_attempts_count')
      self.second_factor_locked_at = result.fetch('second_factor_locked_at')
      self.clear_attribute_changes([:second_factor_attempts_count, :second_factor_locked_at])
    end

    nil
  end

  MINIMUM_LIKELY_ENCRYPTED_DATA_LENGTH = 1000

  def broken_personal_key?
    window_start = IdentityConfig.store.broken_personal_key_window_start
    window_finish = IdentityConfig.store.broken_personal_key_window_finish
    last_personal_key_at = self.encrypted_recovery_code_digest_generated_at

    if active_profile.present?
      encrypted_pii_too_short =
        active_profile.encrypted_pii_recovery.present? &&
        active_profile.encrypted_pii_recovery.length < MINIMUM_LIKELY_ENCRYPTED_DATA_LENGTH

      inside_broken_key_window =
        (!last_personal_key_at || last_personal_key_at < window_finish) &&
        (window_start..window_finish).cover?(active_profile.verified_at)

      encrypted_pii_too_short || inside_broken_key_window
    else
      false
    end
  end

  # To send emails asynchronously via ActiveJob.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_now_or_later
  end

  #
  # Decoration methods
  #
  def email_language_preference_description
    if I18n.locale_available?(email_language)
      # i18n-tasks-use t('account.email_language.name.en')
      # i18n-tasks-use t('account.email_language.name.es')
      # i18n-tasks-use t('account.email_language.name.fr')
      I18n.t("account.email_language.name.#{email_language}")
    else
      I18n.t('account.email_language.name.en')
    end
  end

  def visible_email_addresses
    email_addresses.filter do |email_address|
      email_address.confirmed? || !email_address.confirmation_period_expired?
    end
  end

  def lockout_time_expiration
    second_factor_locked_at + lockout_period
  end

  def active_identity_for(service_provider)
    active_identities.find_by(service_provider: service_provider.issuer)
  end

  def active_or_pending_profile
    active_profile || pending_profile
  end

  def identity_not_verified?
    !identity_verified?
  end

  def identity_verified?(service_provider: nil)
    active_profile.present? && !reproof_for_irs?(service_provider: service_provider)
  end

  def reproof_for_irs?(service_provider:)
    return false unless service_provider&.irs_attempts_api_enabled
    return false unless active_profile.present?
    !active_profile.initiating_service_provider&.irs_attempts_api_enabled
  end

  # This user's most recently activated profile that has also been deactivated
  # due to a password reset, or nil if there is no such profile
  def password_reset_profile
    profile = profiles.where.not(activated_at: nil).order(activated_at: :desc).first
    profile if profile&.password_reset?
  end

  def qrcode(otp_secret_key)
    options = {
      issuer: APP_NAME,
      otp_secret_key: otp_secret_key,
      digits: TwoFactorAuthenticatable::OTP_LENGTH,
      interval: IdentityConfig.store.totp_code_interval,
    }
    url = ROTP::TOTP.new(otp_secret_key, options).provisioning_uri(
      EmailContext.new(self).last_sign_in_email_address.email,
    )
    qrcode = RQRCode::QRCode.new(url)
    qrcode.as_png(size: 240).to_data_url
  end

  def locked_out?
    second_factor_locked_at.present? && !lockout_period_expired?
  end

  def no_longer_locked_out?
    second_factor_locked_at.present? && lockout_period_expired?
  end

  def recent_events
    events = Event.where(user_id: id).order('created_at DESC').limit(MAX_RECENT_EVENTS).
      map(&:decorate)
    (events + identity_events).sort_by(&:happened_at).reverse
  end

  def identity_events
    identities.includes(:service_provider_record).order('last_authenticated_at DESC')
  end

  def recent_devices
    @recent_devices ||= devices.order(last_used_at: :desc).limit(MAX_RECENT_DEVICES).
      map(&:decorate)
  end

  def has_devices?
    !recent_devices.empty?
  end

  # Returns the number of times the user has signed in, corresponding to the `sign_in_before_2fa`
  # event.
  #
  # A `since` time argument is required, to optimize performance based on database indices for
  # querying a user's events.
  #
  # @param [ActiveSupport::TimeWithZone] since Time window to query user's events
  def sign_in_count(since:)
    events.where(event_type: :sign_in_before_2fa).where(created_at: since..).count
  end

  def second_last_signed_in_at
    events.where(event_type: 'sign_in_after_2fa').
      order(created_at: :desc).limit(2).pluck(:created_at).second
  end

  def connected_apps
    identities.not_deleted.includes(:service_provider_record).order('created_at DESC')
  end

  def delete_account_bullet_key
    if identity_verified?
      I18n.t('users.delete.bullet_2_verified', app_name: APP_NAME)
    else
      I18n.t('users.delete.bullet_2_basic', app_name: APP_NAME)
    end
  end
  # End moved from UserDecorator

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

  def analytics
    @analytics ||= Analytics.new(user: self, request: nil, session: {}, sp: nil)
  end

  def send_email_to_all_addresses(user_mailer_template)
    confirmed_email_addresses.each do |email_address|
      UserMailer.with(
        user: self,
        email_address: email_address,
      ).send(user_mailer_template).
        deliver_now_or_later
    end
  end

  def reload(...)
    remove_instance_variable(:@active_profile) if defined?(@active_profile)
    remove_instance_variable(:@pending_profile) if defined?(@pending_profile)
    super(...)
  end

  private

  def lockout_period
    IdentityConfig.store.lockout_period_in_minutes.minutes
  end

  def lockout_period_expired?
    lockout_time_expiration < Time.zone.now
  end
end
