class OtpDeliverySelectionForm
  include ActiveModel::Model

  attr_reader :otp_delivery_preference

  validates :otp_delivery_preference, inclusion: { in: %w[sms voice] }

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.otp_delivery_preference = params[:otp_delivery_preference]
    self.resend = params[:resend]

    @success = valid?

    if success && otp_delivery_preference_changed?
      user_attributes = { otp_delivery_preference: otp_delivery_preference }
      UpdateUser.new(user: user, attributes: user_attributes).call
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_writer :otp_delivery_preference
  attr_accessor :resend
  attr_reader :success, :user

  def otp_delivery_preference_changed?
    otp_delivery_preference != user.otp_delivery_preference
  end

  def extra_analytics_attributes
    {
      otp_delivery_preference: otp_delivery_preference,
      resend: resend,
    }
  end
end
