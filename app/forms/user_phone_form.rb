class UserPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include OtpDeliveryPreferenceValidator
  include RememberDeviceConcern

  validates :otp_delivery_preference, inclusion: { in: %w[voice sms] }

  attr_accessor :phone, :international_code, :otp_delivery_preference,
                :otp_make_default_number, :phone_configuration

  def initialize(user, phone_configuration)
    self.user = user
    self.phone_configuration = phone_configuration
    if phone_configuration.nil?
      self.otp_delivery_preference = user.otp_delivery_preference
    else
      prefill_phone_number(phone_configuration)
    end
    self.otp_make_default_number = true if default_phone_configuration?
  end

  def submit(params)
    ingest_submitted_params(params)

    success = valid?
    self.phone = submitted_phone unless success

    revoke_remember_device(user) if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def delivery_preference_sms?
    return true if phone_configuration.blank?
    phone_configuration&.delivery_preference == 'sms'
  end

  def delivery_preference_voice?
    phone_configuration&.delivery_preference == 'voice'
  end

  def already_has_phone?
    formatted_user_phone != phone && user.phone_configurations.map(&:phone).include?(phone)
  end

  def phone_config_changed?
    return true if formatted_user_phone != phone
    return true if phone_configuration&.delivery_preference != otp_delivery_preference
    return true if otp_make_default_number && !default_phone_configuration?
    false
  end

  # :reek:FeatureEnvy
  def masked_number
    phone_number = phone_configuration == nil ? nil : phone_configuration.phone
    return '' if !phone_number || phone_number.blank?
    "***-***-#{phone_number[-4..-1]}"
  end

  private

  attr_accessor :user, :submitted_phone

  def prefill_phone_number(phone_configuration)
    self.phone = phone_configuration.phone
    self.international_code = Phonelib.parse(phone).country || PhoneFormatter::DEFAULT_COUNTRY
    self.otp_delivery_preference = phone_configuration.delivery_preference
  end

  def ingest_phone_number(params)
    self.international_code = params[:international_code]
    self.submitted_phone = params[:phone]
    self.phone = PhoneFormatter.format(
      submitted_phone,
      country_code: international_code,
    )
  end

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
    }
  end

  def ingest_submitted_params(params)
    ingest_phone_number(params)

    delivery_prefs = params[:otp_delivery_preference]
    default_prefs = params[:otp_make_default_number]

    self.otp_delivery_preference = delivery_prefs if delivery_prefs
    self.otp_make_default_number = true if default_prefs
  end

  def default_phone_configuration?
    phone_configuration == user.default_phone_configuration
  end

  def formatted_user_phone
    phone_configuration&.formatted_phone
  end
end
