class OtpDeliverySelectionForm
  include ActiveModel::Model

  attr_reader :otp_method

  validates :otp_method, inclusion: { in: %w(sms voice) }

  def submit(params)
    self.otp_method = params[:otp_method]
    self.resend = params[:resend]

    @success = valid?

    result
  end

  private

  attr_writer :otp_method
  attr_accessor :resend
  attr_reader :success

  def result
    {
      success: success,
      delivery_method: otp_method,
      resend: resend,
      errors: errors.full_messages
    }
  end
end
