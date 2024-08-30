# frozen_string_literal: true

class NewPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include OtpDeliveryPreferenceValidator

  BLOCKED_PHONE_TYPES = [
    :premium_rate,
    :shared_cost,
  ].freeze

  validates :otp_delivery_preference, inclusion: { in: %w[voice sms] }

  validate :validate_not_voip
  validate :validate_not_duplicate
  validate :validate_not_premium_rate
  validate :validate_recaptcha_token
  validate :validate_allowed_carrier

  attr_reader :phone,
              :international_code,
              :otp_delivery_preference,
              :otp_make_default_number,
              :setup_voice_preference,
              :recaptcha_token,
              :recaptcha_mock_score,
              :recaptcha_assessment_id

  alias_method :setup_voice_preference?, :setup_voice_preference

  def initialize(user:, analytics: nil, setup_voice_preference: false)
    @user = user
    @analytics = analytics
    @otp_delivery_preference = user.otp_delivery_preference
    @otp_make_default_number = false
    @setup_voice_preference = setup_voice_preference
  end

  def submit(params)
    ingest_submitted_params(params)

    success = valid?
    @phone = submitted_phone unless success

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def delivery_preference_sms?
    !OutageStatus.new.vendor_outage?(:sms)
  end

  def delivery_preference_voice?
    OutageStatus.new.vendor_outage?(:sms) || setup_voice_preference?
  end

  # @return [Telephony::PhoneNumberInfo, nil]
  def phone_info
    return @phone_info if defined?(@phone_info)

    if phone.blank? || !IdentityConfig.store.phone_service_check
      @phone_info = nil
    else
      @phone_info = Telephony.phone_info(phone)
    end
  rescue Aws::Pinpoint::Errors::TooManyRequestsException
    @warning_message = 'AWS pinpoint phone info rate limit'
    @phone_info = Telephony::PhoneNumberInfo.new(type: :unknown)
  rescue Aws::Pinpoint::Errors::BadRequestException
    errors.add(:phone, :improbable_phone, type: :improbable_phone)
    @redacted_phone = StringRedacter.redact_alphanumeric(phone)
    @phone_info = Telephony::PhoneNumberInfo.new(type: :unknown)
  end

  private

  attr_reader :user, :submitted_phone, :analytics

  def ingest_phone_number(params)
    @international_code = params[:international_code]
    @submitted_phone = params[:phone]
    @phone = PhoneFormatter.format(submitted_phone, country_code: international_code)
  end

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
      phone_type: phone_info&.type, # comes from pinpoint API
      types: parsed_phone.types, # comes from Phonelib gem
      carrier: phone_info&.carrier,
      country_code: parsed_phone.country,
      area_code: parsed_phone.area_code,
      pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
    }.tap do |extra|
      extra[:redacted_phone] = @redacted_phone if @redacted_phone
      extra[:warn] = @warning_message if @warning_message
    end
  end

  def validate_not_voip
    return if phone.blank? || !IdentityConfig.store.phone_service_check

    if phone_info.type == :voip
      errors.add(:phone, I18n.t('errors.messages.voip_phone'), type: :voip_phone)
    elsif phone_info.error
      errors.add(:phone, I18n.t('errors.messages.voip_check_error'), type: :voip_check_error)
    end
  end

  def validate_allowed_carrier
    return if phone.blank? || phone_info.blank?

    if IdentityConfig.store.phone_carrier_registration_blocklist_array.include?(phone_info.carrier)
      errors.add(:phone, I18n.t('errors.messages.phone_carrier'), type: :phone_carrier)
    end
  end

  def validate_not_duplicate
    current_user_phones = user.phone_configurations.map do |phone_configuration|
      PhoneFormatter.format(phone_configuration.phone)
    end

    return unless current_user_phones.include?(phone)
    errors.add(:phone, I18n.t('errors.messages.phone_duplicate'), type: :phone_duplicate)
  end

  def validate_not_premium_rate
    if (parsed_phone.types & BLOCKED_PHONE_TYPES).present?
      errors.add(:phone, I18n.t('errors.messages.premium_rate_phone'), type: :premium_rate_phone)
    end
  end

  def validate_recaptcha_token
    return if !validate_recaptcha_token?
    _response, assessment_id = recaptcha_form.submit(recaptcha_token)
    @recaptcha_assessment_id = assessment_id
    errors.merge!(recaptcha_form)
  end

  def recaptcha_form
    @recaptcha_form ||= PhoneRecaptchaForm.new(parsed_phone:, **recaptcha_form_args)
  end

  def recaptcha_form_args
    args = { analytics: }
    if IdentityConfig.store.recaptcha_mock_validator
      args.merge(form_class: RecaptchaMockForm, score: recaptcha_mock_score)
    elsif FeatureManagement.recaptcha_enterprise?
      args.merge(form_class: RecaptchaEnterpriseForm)
    else
      args
    end
  end

  def validate_recaptcha_token?
    FeatureManagement.phone_recaptcha_enabled? ||
      IdentityConfig.store.recaptcha_mock_validator
  end

  def parsed_phone
    @parsed_phone ||= Phonelib.parse(phone)
  end

  def ingest_submitted_params(params)
    ingest_phone_number(params)

    delivery_prefs = params[:otp_delivery_preference]
    default_prefs = params[:otp_make_default_number]

    @otp_delivery_preference = delivery_prefs if delivery_prefs
    @otp_make_default_number = true if default_prefs
    @recaptcha_token = params[:recaptcha_token]
    @recaptcha_mock_score = params[:recaptcha_mock_score].to_f if params.key?(:recaptcha_mock_score)
  end

  def confirmed_phone?
    false
  end
end
