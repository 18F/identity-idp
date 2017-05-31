class ResetPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  attr_accessor :reset_password_token

  validate :valid_token

  def initialize(user)
    @user = user
    self.reset_password_token = @user.reset_password_token
  end

  def submit(params)
    submitted_password = params[:password]

    self.password = submitted_password

    FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :success

  def valid_token
    return if user.reset_password_period_valid?

    errors.add(:reset_password_token, 'token_expired')
  end

  def extra_analytics_attributes
    {
      user_id: user.uuid,
      active_profile: user.active_profile.present?,
      confirmed: user.confirmed?,
    }
  end
end
