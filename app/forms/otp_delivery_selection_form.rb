class OtpDeliverySelectionForm
  include ActiveModel::Model
  include OtpDeliveryPreferenceValidator

  attr_reader :otp_delivery_preference, :phone, :context

  validates :otp_delivery_preference, inclusion: { in: %w[sms voice] }
  validates :phone, presence: true

  def initialize(user, phone_to_deliver_to, context)
    @user = user
    @phone = PhoneFormatter.format(phone_to_deliver_to)
    @context = context
  end

  def submit(params)
    self.otp_delivery_preference = params[:otp_delivery_preference]
    self.resend = params[:resend]

    @success = valid?

    if !otp_delivery_preference_supported? && phone_number_capabilities.supports_sms?
      change_otp_delivery_preference_to_sms
    end

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_writer :otp_delivery_preference
  attr_accessor :resend
  attr_reader :success, :user

  def change_otp_delivery_preference_to_sms
    user_attributes = { otp_delivery_preference: 'sms' }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
      resend: resend,
      country_code: parsed_phone.country,
      area_code: parsed_phone.area_code,
      context: context,
      pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
    }
  end

  def parsed_phone
    @parsed_phone ||= Phonelib.parse(phone)
  end

  def confirmed_phone?
    UserSessionContext.authentication_or_reauthentication_context?(context)
  end
end
