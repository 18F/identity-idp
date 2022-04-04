class TwoFactorOptionsForm
  include ActiveModel::Model

  attr_reader :selection
  attr_reader :configuration_id

  validates :selection, inclusion: { in: %w[phone sms voice auth_app piv_cac
                                            webauthn webauthn_platform
                                            backup_code] }

  def initialize(user)
    self.user = user
  end

  def submit(params)
    self.selection = Array(params[:selection])

    success = valid?
    update_otp_delivery_preference_for_user if success && user_needs_updating?

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :user
  attr_writer :selection

  def extra_analytics_attributes
    {
      selection: selection,
    }
  end

  def selection_is_voice_or_sms
    %w[voice sms] & selection
  end

  def user_needs_updating?
    selection_is_voice_or_sms.present? &&
      selection_is_voice_or_sms.first != user.otp_delivery_preference
  end

  def update_otp_delivery_preference_for_user
    user_attributes = { otp_delivery_preference: selection_is_voice_or_sms.first }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end
end
