# frozen_string_literal: true

class PasswordResetEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :email

  def initialize(email)
    @email = email
  end

  def resend
    'true'
  end

  def submit
    FormResponse.new(
      success: valid?,
      errors:,
      extra: extra_analytics_attributes,
      serialize_error_details_only: false,
    )
  end

  private

  attr_writer :email

  def extra_analytics_attributes
    {
      user_id: user&.uuid || 'nonexistent-uuid',
      confirmed: user&.confirmed? == true,
      active_profile: user&.active_profile.present?,
    }
  end

  def user
    @user ||= User.find_with_email(email)
  end
end
