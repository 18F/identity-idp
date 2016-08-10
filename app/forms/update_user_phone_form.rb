class UpdateUserPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include CustomFormHelpers::PhoneHelpers

  attr_accessor :phone, :sms_otp_delivery
  attr_reader :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.phone = @user.phone
    self.sms_otp_delivery = @user.sms_otp_delivery
  end

  def submit(params)
    check_phone_change(params)

    check_sms_preference_change(params)

    valid?
  end
end
