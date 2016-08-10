class TwoFactorSetupForm
  include ActiveModel::Model
  include FormPhoneValidator

  attr_accessor :phone, :sms_otp_delivery

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.phone = params[:phone].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )
    self.sms_otp_delivery = params[:sms_otp_delivery].to_i == 1
    valid?
  end
end
