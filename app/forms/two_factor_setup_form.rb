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

    if success && otp_delivery_preference_changed?
      user_attributes = { otp_delivery_preference: otp_method }
      UpdateUser.new(user: user, attributes: user_attributes).call
    end

    result
  end

  private

  attr_reader :success, :user

  def otp_delivery_preference_changed?
    otp_method != user.otp_delivery_preference
  end

  def result
    {
      success: success,
      error: errors.messages.values.flatten.first,
      otp_method: otp_method
    }
  end
end
