class AddEmailConfirmTokenValidator
  include ActiveModel::Model

  validate :token_found
  validate :token_not_expired

  def initialize(email_address)
    @email_address = email_address
    @user = email_address&.user
  end

  def submit
    @success = valid? && @email_address

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :user
  attr_reader :success

  def extra_analytics_attributes
    {
      user_id: user&.uuid,
    }
  end

  def user_valid?
    user.errors.empty?
  end

  def confirmation_token; end

  def token_found
    errors.add(:confirmation_token, :not_found) unless @email_address
  end

  def token_not_expired
    errors.add(:confirmation_token, :expired) if confirmation_period_expired?
  end

  def confirmation_period_expired?
    return unless @email_address
    expiration_time = @email_address.confirmation_sent_at + email_valid_for_duration
    Time.zone.now > expiration_time
  end

  def email_valid_for_duration
    Figaro.env.add_email_link_valid_for_hours.to_i.hours
  end
end
