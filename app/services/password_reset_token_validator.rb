# frozen_string_literal: true

class PasswordResetTokenValidator
  include ActiveModel::Model

  validates :user, presence: { message: 'invalid_token' }
  validate :valid_token, if: :user

  def initialize(user)
    @user = user
  end

  def submit
    FormResponse.new(
      success: valid?,
      errors:,
      extra: { user_id: user&.uuid },
      serialize_error_details_only: false,
    )
  end

  private

  attr_accessor :user

  def valid_token
    return if user.reset_password_period_valid?
    errors.add(:user, 'token_expired', type: :token_expired)
  end
end
