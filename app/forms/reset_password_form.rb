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
    self.password = params[:password]

    @success = valid?

    handle_valid_password if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :success

  def valid_token
    if !user.persisted?
      # If the user is not saved in the database, that means looking them up by
      # their token failed
      errors.add(:reset_password_token, 'invalid_token')
    elsif !user.reset_password_period_valid?
      errors.add(:reset_password_token, 'token_expired')
    end
  end

  def handle_valid_password
    update_user
    mark_profile_inactive
  end

  def update_user
    attributes = { password: password }
    attributes[:confirmed_at] = Time.zone.now unless user.confirmed?
    UpdateUser.new(user: user, attributes: attributes).call
  end

  def mark_profile_inactive
    user.active_profile&.deactivate(:password_reset)
  end

  def extra_analytics_attributes
    { user_id: user.uuid }
  end
end
