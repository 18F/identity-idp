class AddPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include OtpDeliveryPreferenceValidator

  validates :otp_delivery_preference, inclusion: { in: %w[voice sms] }

  attr_reader :phone, :international_code, :otp_delivery_preference, :otp_make_default_number

  def initialize(user)
    @user = user
  end

  def submit(params)
    ingest_submitted_params(params)
    success = valid?
    @phone = submitted_phone unless success
    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :submitted_phone

  def ingest_submitted_params(params)
    ingest_phone_number(params)

    delivery_prefs = params[:otp_delivery_preference]
    default_prefs = params[:otp_make_default_number]

    @otp_delivery_preference = delivery_prefs if delivery_prefs
    @otp_make_default_number = true if default_prefs
  end

  def ingest_phone_number(params)
    @international_code = params[:international_code]
    @submitted_phone = params[:phone]
    @phone = PhoneFormatter.format(
      submitted_phone,
      country_code: international_code,
    )
  end

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
      otp_make_default_number: otp_make_default_number,
    }
  end
end
