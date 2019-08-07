class AddPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include OtpDeliveryPreferenceValidator
  include RememberDeviceConcern

  validates :otp_delivery_preference, inclusion: { in: %w[voice sms] }

  attr_accessor :phone, :international_code, :otp_delivery_preference,
                :otp_make_default_number, :user

  def initialize(user)
    self.user = user
  end

  def submit(params)
    ingest_phone_number_params(params)

    success = valid?
    self.phone = submitted_phone unless success

    revoke_remember_device(user) if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :submitted_phone

  def ingest_phone_number_params(params)
    self.otp_delivery_preference = params[:otp_delivery_preference] || 'sms'
    self.international_code = params[:international_code]
    self.otp_make_default_number = params[:otp_make_default_number]
    self.submitted_phone = params[:phone]
    self.phone = PhoneFormatter.format(
      params[:phone],
      country_code: international_code,
    )
  end

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
    }
  end
end
