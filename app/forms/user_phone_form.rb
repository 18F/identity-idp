class UserPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include OtpDeliveryPreferenceValidator

  validates :otp_delivery_preference, inclusion: { in: %w[voice sms] }

  attr_accessor :phone, :international_code, :otp_delivery_preference, :phone_configuration

  def initialize(user, phone_configuration)
    self.user = user
    self.phone_configuration = phone_configuration
    if phone_configuration.nil?
      self.otp_delivery_preference = user.otp_delivery_preference
    else
      self.phone = phone_configuration.phone
      self.international_code = Phonelib.parse(phone).country || PhoneFormatter::DEFAULT_COUNTRY
      self.otp_delivery_preference = phone_configuration.delivery_preference
    end
  end

  def submit(params)
    ingest_submitted_params(params)

    success = valid?
    self.phone = submitted_phone unless success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def phone_changed?
    formatted_user_phone != phone
  end

  private

  attr_accessor :user, :submitted_phone

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
    }
  end

  def ingest_submitted_params(params)
    self.international_code = params[:international_code]
    self.submitted_phone = params[:phone]
    self.phone = PhoneFormatter.format(
      submitted_phone,
      country_code: international_code
    )

    tfa_prefs = params[:otp_delivery_preference]

    self.otp_delivery_preference = tfa_prefs if tfa_prefs
  end

  def formatted_user_phone
    phone_configuration&.formatted_phone
  end
end
