class NewPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include OtpDeliveryPreferenceValidator

  validates :otp_delivery_preference, inclusion: { in: %w[voice sms] }

  validate :validate_not_voip

  attr_accessor :phone, :international_code, :otp_delivery_preference,
                :otp_make_default_number

  def initialize(user)
    self.user = user
    self.otp_delivery_preference = user.otp_delivery_preference
    self.otp_make_default_number = false
  end

  def submit(params)
    ingest_submitted_params(params)

    success = valid?
    self.phone = submitted_phone unless success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def delivery_preference_sms?
    true
  end

  def delivery_preference_voice?
    false
  end

  def already_has_phone?
    user.phone_configurations.map(&:phone).include?(phone)
  end

  def masked_number
    phone_number = nil
    phone_number = phone_configuration.phone unless phone_configuration.nil?
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
      phone_type: @phone_info&.type,
      carrier: @phone_info&.carrier,
      country_code: parsed_phone.country,
      area_code: parsed_phone.area_code,
    }
  end

  def validate_not_voip
    return if phone.blank? || !FeatureManagement.voip_block?

    @phone_info = Telephony.phone_info(phone)

    if @phone_info.type == :voip &&
       !FeatureManagement.voip_allowed_phones.include?(parsed_phone.e164)
      errors.add(:phone, I18n.t('errors.messages.voip_check_error'))
    elsif @phone_info.error
      errors.add(:phone, I18n.t('errors.messages.voip_phone'))
    end
  end

  def parsed_phone
    @parsed_phone ||= Phonelib.parse(phone)
  end

  def ingest_submitted_params(params)
    ingest_phone_number(params)

    delivery_prefs = params[:otp_delivery_preference]
    default_prefs = params[:otp_make_default_number]

    self.otp_delivery_preference = delivery_prefs if delivery_prefs
    self.otp_make_default_number = true if default_prefs
  end
end
