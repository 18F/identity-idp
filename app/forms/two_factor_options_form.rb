class TwoFactorOptionsForm
  include ActiveModel::Model

  attr_reader :selection
  attr_reader :configuration_id

  validates :selection, inclusion: { in: %w[voice sms auth_app piv_cac webauthn] }

  def initialize(user)
    self.user = user
  end

  def submit(params)
    self.selection = params[:selection]

    success = valid?

    update_otp_delivery_preference_for_user if success && user_needs_updating?

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  def selected?(type)
    type.to_s == (selection || 'sms')
  end

  private

  attr_accessor :user
  attr_writer :selection

  def extra_analytics_attributes
    {
      selection: selection,
    }
  end

  def user_needs_updating?
    return false unless %w[voice sms].include?(selection)
    return false if selection == user.mfa.phone_configurations.first&.delivery_preference
    selection != user.otp_delivery_preference
  end

  def update_otp_delivery_preference_for_user
    user_attributes = { otp_delivery_preference: selection }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end
end
