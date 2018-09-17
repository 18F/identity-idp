class OtpDeliveryPreferenceUpdater
  def initialize(user:, preference:, context:)
    @user = user
    @preference = preference
    @context = context
  end

  def call
    user_attributes = { otp_delivery_preference: preference }
    UpdateUser.new(user: user, attributes: user_attributes).call if should_update_user?
  end

  private

  attr_reader :user, :preference, :context

  def should_update_user?
    return false unless user
    otp_delivery_preference_changed?
  end

  def otp_delivery_preference_changed?
    return true if preference != user.otp_delivery_preference
    phone_configuration = user.phone_configurations.first
    phone_configuration.present? && preference != phone_configuration.delivery_preference
  end
end
