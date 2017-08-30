class OtpDeliverySelectionForm
  include ActiveModel::Model

  attr_reader :otp_delivery_preference

  validates :otp_delivery_preference, inclusion: { in: %w[sms voice] }

  def initialize(user, phone_to_deliver_to, context)
    @user = user
    @phone_to_deliver_to = phone_to_deliver_to
    @context = context
  end

  def submit(params)
    self.otp_delivery_preference = params[:otp_delivery_preference]
    self.resend = params[:resend]

    @success = valid?

    if should_update_user?
      user_attributes = { otp_delivery_preference: otp_delivery_preference }
      UpdateUser.new(user: user, attributes: user_attributes).call
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_writer :otp_delivery_preference
  attr_accessor :resend
  attr_reader :success, :user, :phone_to_deliver_to, :context

  def idv_context?
    context == 'idv'
  end

  def otp_delivery_preference_changed?
    otp_delivery_preference != user.otp_delivery_preference
  end

  def should_update_user?
    success && otp_delivery_preference_changed? && !idv_context?
  end

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
      resend: resend,
      country_code: parsed_phone.country_code,
      area_code: parsed_phone.area_code,
      context: context,
    }
  end

  def parsed_phone
    @_parsed_phone ||= Phonelib.parse(phone_to_deliver_to)
  end
end
