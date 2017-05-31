class EmailConfirmationTokenValidator
  include ActiveModel::Model

  validate :token_not_expired

  delegate :confirmation_token, to: :user

  def initialize(user)
    @user = user
  end

  def submit
    @success = valid? && user_valid?

    FormResponse.new(success: success, errors: form_errors, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :user
  attr_reader :success

  def form_errors
    errors.messages.merge!(user.errors.messages)
  end

  def extra_analytics_attributes
    {
      user_id: user.uuid,
      existing_user: user.confirmed?,
    }
  end

  def user_valid?
    user.errors.empty?
  end

  def token_not_expired
    errors.add(:confirmation_token, :expired) if user.confirmation_period_expired?
  end
end
