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
    return if user.reset_password_period_valid?

    errors.add(:reset_password_token, 'token_expired')
  end

  def handle_valid_password
    create_password_changed_event
    update_user
    increment_password_metrics
    mark_profile_inactive
    notify_user_of_password_change_via_email
  end

  def create_password_changed_event
    Event.create(user_id: user.id, event_type: :password_changed)
  end

  def update_user
    attributes = { password: password }
    attributes[:confirmed_at] = Time.zone.now unless user.confirmed?
    UpdateUser.new(user: user, attributes: attributes).call
  end

  def increment_password_metrics
    PasswordMetricsIncrementer.new(password).increment_password_metrics
  end

  def mark_profile_inactive
    user.active_profile&.deactivate(:password_reset)
  end

  def notify_user_of_password_change_via_email
    UserMailer.password_changed(user).deliver_later
  end

  def extra_analytics_attributes
    { user_id: user.uuid }
  end
end
