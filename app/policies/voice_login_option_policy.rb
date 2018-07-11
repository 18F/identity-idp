class VoiceLoginOptionPolicy
  def initialize(user)
    @user = user
  end

  def configured?
    user_has_a_phone_number_that_we_can_call?
  end

  private

  attr_reader :user

  def user_has_a_phone_number_that_we_can_call?
    phone = user.phone
    phone.present? && !PhoneNumberCapabilities.new(phone).sms_only?
  end
end
