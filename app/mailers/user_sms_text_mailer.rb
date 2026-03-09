# frozen_string_literal: true

class UserSmsTextMailer < ActionMailer::Base
  include ActionView::Helpers::DateHelper
  include Rails.application.routes.url_helpers

  def mail_to
    mail to: 'NO EMAIL'
  end

  alias_method :account_deletion_cancelled, :mail_to
  alias_method :account_deleted_notice, :mail_to
  alias_method :duplicate_profile_created, :mail_to
  alias_method :duplicate_profile_sign_in_attempted, :mail_to
  alias_method :personal_key_regeneration_notice, :mail_to
  alias_method :personal_key_sign_in_notice, :mail_to

  def account_deletion_started
    @interval = account_reset_wait_period
    mail_to
  end

  def confirmation_ipp_enrollment_result
    @proof_date = I18n.l(Time.current, format: :sms_date)
    @contact_number = IdentityConfig.store.idv_contact_phone_number
    @reference_string = '765261560'
    mail_to
  end

  def doc_auth_link
    @link = url_for(idv_hybrid_mobile_entry_url) + "?document-capture-session=#{SecureRandom.uuid}"
    @sp_or_app_name = 'Sample SAML Sinatra SP'
    mail_to
  end

  def authentication_otp
    @code = OtpCodeGenerator.generate_digits(TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
    @expiration = otp_expiration
    @domain = domain
    mail_to
  end

  def confirmation_otp
    @code = OtpCodeGenerator.generate_alphanumeric_digits(
      TwoFactorAuthenticatable::DIRECT_OTP_LENGTH,
    )
    @expiration = otp_expiration
    @domain = domain
    mail_to
  end

  def url_options
    { host: domain, protocol: 'https' }
  end

  private

  def account_reset_wait_period
    current_time = Time.zone.now
    distance_of_time_in_words(
      current_time,
      current_time + IdentityConfig.store.account_reset_wait_period_days.days,
      true,
      accumulate_on: :hours,
    )
  end

  def domain
    IdentityConfig.store.domain_name
  end

  def otp_expiration
    TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES
  end
end
