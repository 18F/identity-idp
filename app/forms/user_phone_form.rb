class UserPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include OtpDeliveryPreferenceValidator

  attr_accessor :phone, :international_code, :otp_delivery_preference

  def initialize(user)
    self.user = user
    self.phone = user.phone
    self.international_code = Phonelib.parse(phone).country || PhoneFormatter::DEFAULT_COUNTRY
    self.otp_delivery_preference = user.otp_delivery_preference
  end

  def submit(params)
    ingest_submitted_params(params)

    success = valid?

    self.phone = submitted_phone unless success
    update_otp_delivery_preference_for_user if otp_delivery_preference_changed? && success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def phone_changed?
    user.phone != phone
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
    self.phone = PhoneFormatter.new.format(
      submitted_phone,
      country_code: international_code
    )
    self.otp_delivery_preference = params[:otp_delivery_preference]
  end

  def otp_delivery_preference_changed?
    otp_delivery_preference != user.otp_delivery_preference
  end

  def update_otp_delivery_preference_for_user
    user_attributes = { otp_delivery_preference: otp_delivery_preference }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end
end
