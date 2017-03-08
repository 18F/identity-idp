class OtpDeliverySelectionForm
  include ActiveModel::Model

  attr_reader :otp_method

  validates :otp_method, inclusion: { in: %w(sms voice) }

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.otp_method = params[:otp_method]
    self.resend = params[:resend]

    @success = valid?

    if success && otp_delivery_preference_changed?
      user_attributes = { otp_delivery_preference: otp_method }
      UpdateUser.new(user: user, attributes: user_attributes).call
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_writer :otp_method
  attr_accessor :resend
  attr_reader :success, :user

  def otp_delivery_preference_changed?
    otp_method != user.otp_delivery_preference
  end

  def extra_analytics_attributes
    {
      delivery_method: otp_method,
      resend: resend,
    }
  end
end
