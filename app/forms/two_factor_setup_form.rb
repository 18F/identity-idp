class TwoFactorSetupForm
  include ActiveModel::Model
  include FormPhoneValidator

  attr_accessor :phone, :delivery_method

  def initialize(user)
    @user = user
  end

  def submit(params)
    self.phone = params[:phone].phony_formatted(
      format: :international, normalize: :US, spaces: ' '
    )
    self.delivery_method = params[:voice].present? ? :voice : :sms

    valid?
  end
end
