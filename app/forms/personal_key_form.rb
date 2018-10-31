class PersonalKeyForm
  include ActiveModel::Model
  include PersonalKeyValidator

  attr_accessor :personal_key

  validate :check_personal_key

  def initialize(user, personal_key = nil)
    @user = user
    @personal_key = normalize_personal_key(personal_key)
  end

  def submit
    @success = valid?

    reset_sensitive_fields unless success
    send_personal_key_sign_in_notification if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :success

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'personal key',
    }
  end

  def reset_sensitive_fields
    self.personal_key = nil
  end

  def send_personal_key_sign_in_notification
    UserMailer.personal_key_sign_in(user.email_address.email).deliver_now
    MfaContext.new(user).phone_configurations.each do |phone_configuration|
      SmsPersonalKeySignInNotifierJob.perform_now(phone: phone_configuration.phone)
    end
  end
end
