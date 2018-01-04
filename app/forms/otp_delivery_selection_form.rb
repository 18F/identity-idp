class OtpDeliverySelectionForm
  include ActiveModel::Model
  include OtpDeliveryPreferenceValidator

  attr_reader :otp_delivery_preference

  validates :otp_delivery_preference, inclusion: { in: %w[sms voice] }
  validates :phone, presence: true

  def initialize(user, phone_to_deliver_to, context)
    @user = user
    @phone = phone_to_deliver_to
    @context = context
  end

  def submit(params)
    self.otp_delivery_preference = params[:otp_delivery_preference]
    self.resend = params[:resend]

    @success = valid?

    change_otp_delivery_preference_to_sms if unsupported_phone?
    update_otp_delivery_preference if should_update_user?

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_writer :otp_delivery_preference
  attr_accessor :resend
  attr_reader :success, :user, :phone, :context

  def change_otp_delivery_preference_to_sms
    user_attributes = { otp_delivery_preference: 'sms' }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end

  def unsupported_phone?
    error_messages = errors.messages
    return false unless error_messages.key?(:phone)

    error_messages[:phone].first != I18n.t('errors.messages.missing_field')
  end

  def update_otp_delivery_preference
    user_attributes = { otp_delivery_preference: otp_delivery_preference }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end

  def idv_context?
    context == 'idv'
  end

  def otp_delivery_preference_changed?
    otp_delivery_preference != user.otp_delivery_preference
  end

  def should_update_user?
    return false if unsupported_phone?
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
    @_parsed_phone ||= Phonelib.parse(phone)
  end
end
