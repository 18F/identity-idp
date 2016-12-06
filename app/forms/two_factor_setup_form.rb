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
    self.otp_method = params[:otp_method]

    @success = valid?

    result
  end

  private

  attr_reader :success

  def result
    {
      success: success,
      error: errors.messages.values.flatten.first,
      otp_method: otp_method
    }
  end
end
