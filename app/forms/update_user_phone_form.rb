class UpdateUserPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator
  include CustomFormHelpers::PhoneHelpers

  attr_accessor :phone, :phone_sms_enabled
  attr_reader :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.phone = @user.phone
    self.phone_sms_enabled = @user.phone_sms_enabled
  end

  def submit(params)
    check_phone_change(params)

    check_sms_preference_change(params)

    valid?
  end
end
