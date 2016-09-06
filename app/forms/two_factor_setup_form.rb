class TwoFactorSetupForm
  include ActiveModel::Model
  include FormPhoneValidator

  attr_accessor :phone, :otp_method

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.phone = params[:phone].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )
    self.otp_method = params[:otp_method] == 'voice' ? :voice : :sms

    valid?
  end
end
