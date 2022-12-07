class OtpVerificationForm
  include ActiveModel::Model

  validates :code, presence: true
  validate :validate_code_length
  validate :validate_code_matches_format
  validate :validate_user_otp_presence
  validate :validate_user_otp_expiration
  validate :validate_code_equals_user_otp

  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    success = valid?

    user.clear_direct_otp if success

    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_analytics_attributes,
      serialize_error_details_only: true,
    )
  end

  private

  attr_reader :code, :user

  def validate_code_length
    return if code.blank? || code.size == TwoFactorAuthenticatable::DIRECT_OTP_LENGTH
    errors.add(:code, :incorrect_length, type: :incorrect_length)
  end

  def validate_code_matches_format
    return if code.blank? || code.match?(/^[0-9]+/i)
    errors.add(:code, :pattern_mismatch, type: :pattern_mismatch)
  end

  def validate_user_otp_presence
    return if user.direct_otp.present?
    errors.add(:code, :user_otp_missing, type: :user_otp_missing)
  end

  def validate_user_otp_expiration
    return if !otp_expired?
    errors.add(:code, :user_otp_expired, type: :user_otp_expired)
  end

  def validate_code_equals_user_otp
    return if code.blank? ||
              user.direct_otp.blank? ||
              ActiveSupport::SecurityUtils.secure_compare(user.direct_otp, code)
    errors.add(:code, :incorrect, type: :incorrect)
  end

  def otp_expired?
    return if user.direct_otp_sent_at.blank?
    (user.direct_otp_sent_at + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS).past?
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'otp_code',
    }
  end
end
